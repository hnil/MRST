classdef TransportModelDG < TransportModel
    
    properties
        discretization = []    % Discretization
        dgVariables    = {'s'} % Transport variables we discretize with dG
        limiters               % Limiters
        storeUnlimited = false % Store unlimited state for plotting/debug
    end
    
    methods
        %-----------------------------------------------------------------%
        function model = TransportModelDG(parent, varargin)
            % Parent model initialization
            model = model@TransportModel(parent); 
            % Default limiters
            names    = model.dgVariables;
            limits   = {[0,1]}; % Limiter limits
            tol      = 0;       % Limiter tolerances
            limiters = [];      % Add limiters
            limiters = addLimiter(limiters           , ... % TVB limiter
                                  'type'     , 'tvb' , ...
                                  'variables', names , ...
                                  'limits'   , limits, ...
                                  'tol'      , tol   );
            limiters = addLimiter(limiters            , ... % Scale limiter
                                  'type'     , 'scale', ...
                                  'variables', names  , ...
                                  'limits'   , limits , ...
                                  'tol'      , tol    );
            model.limiters       = limiters;
            model.storeUnlimited = false;
            % Merge options
            [model, discretizationArgs] = merge_options(model, varargin{:});
            % Construct discretization
            if isempty(model.discretization)
                model.discretization = DGDiscretization(model.G, discretizationArgs{:});
            end
            % Assign discretization to parentModel
            model.parentModel.discretization = model.discretization;
            % Add phase saturations as dgVariables
            if any(strcmpi(model.dgVariables, 's'))
                phNames = model.parentModel.getPhaseNames();
                for ph = phNames
                    model.dgVariables{end+1} = ['s', ph];
                end
                if strcmpi(model.formulation, 'totalSaturation')
                    model.dgVariables{end+1} = 'sT';
                end
            end
            % Get limiters
            for l = 1:numel(model.limiters)
                limiter = model.limiters(l);
                model.limiters(l).function = getLimiter(model, limiter.type);
            end
            % Set up DG operators
            model.parentModel.operators = setupOperatorsDG(model.discretization  , ...
                                                           model.parentModel.G   , ...
                                                           model.parentModel.rock);
            % Pressure is not solved with DG, make sure to don't store
            % things to state that should be recomputed in pressure step
            model.parentModel.outputFluxes         = false;
            model.parentModel.OutputStateFunctions = {};
        end
        
        %-----------------------------------------------------------------%
        function [fn, index] = getVariableField(model, name, varargin)
            % Get variable fiels, check if it is dof
            isDof = any(strcmpi(name(1:end-3), model.dgVariables));
            if isDof
                lookup = name(1:end-3);
            else
                lookup = name;
            end
            [fn, index] = getVariableField@TransportModel(model, lookup, varargin{:});
            if isDof && ~isempty(fn)
                fn = [fn, 'dof'];
            end
        end
        
        %-----------------------------------------------------------------%
        function groupings = getStateFunctionGroupings(model)
            groupings = model.parentModel.getStateFunctionGroupings();
        end
        
        %-----------------------------------------------------------------%
        function state = validateState(model, state)
            % Set degree in each cell
            state.degree = repmat(model.discretization.degree, model.G.cells.num, 1);
            % Well are treated as dG(0)
            wm = model.parentModel.FacilityModel.WellModels;
            for i = 1:numel(wm)
                state.degree(wm{i}.W.cells,:) = 0;
            end
            % Let parent model do its thing
            state = validateState@TransportModel(model, state);
            % Assign dofs
            state = assignDofFromState(model.discretization, state, model.dgVariables);
        end
        
        %-----------------------------------------------------------------%
        function [vars, names, origin] = getPrimaryVariables(model, state)
            % Get primary variables
            [vars, names, origin] = model.parentModel.getPrimaryVariables(state);
            isParent = strcmp(origin, class(model.parentModel));
            vars     = vars(isParent);
            names    = names(isParent);
            % If saturation is a dG variable, we relace 's' by 'sW', etc
            isSat = strcmpi(model.dgVariables, 's');
            if any(isSat)
                model.dgVariables(isSat) = [];
                phNames = model.parentModel.getPhaseNames();
                for ph = phNames
                    model.dgVariables{end+1} = ['s', ph];
                end
            end
            % Add dof to ending dG variable names
            isDof        = ismember(names, model.dgVariables);
            names(isDof) = cellfun(@(bn) [bn, 'dof'], names(isDof), 'UniformOutput', false);
            % Replace variables with dofs
            origin = origin(isParent);
            isBO   = strcmpi(origin, 'GenericBlackOilModel');
            for i = 1:numel(names)
                if isDof(i)
                    [fn, ~] = model.getVariableField(names{i}, false);
                    if ~isempty(fn)
                        vars{i} = model.getProp(state, names{i});
                    elseif any(strcmpi(names{i}, {'x', 'xdof'})) && isBO(i)
                        error('dG currently does not support disgas/vapoil')
                    end
                end
            end
        end
        
        %-----------------------------------------------------------------%
        function [state, names, origin] = getStateAD(model, state, init)
            if nargin < 3
                init = true;
            end            
            parent = model.parentModel;
            % Get the AD state for this model
            [basevars, basenames, baseorigin] = model.getPrimaryVariables(state);
            isParent   = strcmp(baseorigin, class(parent));
            basevars   = basevars(isParent);
            basenames  = basenames(isParent);
            baseorigin = baseorigin(isParent);
            % Find saturations
            isS = false(size(basevars));
            nph = parent.getNumberOfPhases();
            phase_variable_index = zeros(nph, 1);
            for i = 1:numel(basevars)
                [f, ix] = model.getVariableField(basenames{i}, false);
                if any(strcmpi(f, {'s', 'sdof'}))
                    isS(i) = true;
                    phase_variable_index(ix) = i;
                end
            end
            % Figure out saturation logic
            isP    = strcmp(basenames, 'pressure');
            vars   = basevars;
            names  = basenames;
            origin = baseorigin;
            useTotalSaturation = ....
                strcmpi(model.formulation, 'totalSaturation') && sum(isS) == nph - 1;
            if useTotalSaturation
                % Replace pressure with total saturation
                if any(strcmpi('sT',model.dgVariables))
                    replacement = 'sTdof';
                else
                    replacement = 'sT';
                end
                sTdof       = model.getProp(state, replacement);
                % Replacing
                vars{isP}   = sTdof;
                names{isP}  = replacement;
                origin{isP} = class(model);
            else
                % Remove pressure and skip saturation closure
                vars   = vars(~isP);
                names  = names(~isP);
                origin = origin(~isP);
            end
            if init
                [vars{:}] = model.AutoDiffBackend.initVariablesAD(vars{:});
            end
            if useTotalSaturation
                basevars(~isP) = vars(~isP);
            else
                basevars(~isP) = vars;
            end
            % Evluate basis functions for use later
            state = model.discretization.evaluateBasisFunctions(state);
            dgv   = cellfun(@(dgv) [dgv, 'dof'], model.dgVariables, 'uniformOutput', false);
            isDof = false(size(names));
            [cellMean, cellVars, faceVars] = deal(cell(size(vars)));
            for i = 1:numel(vars)
                if 0
                if any(strcmpi(basenames{i}, dgv))
                    % dG - do evaluation
                    isDof(i)    = true;
                    cellMean{i} = model.discretization.getCellMean(state, basevars{i});
                    cellVars{i} = model.discretization.evaluateProp(state, basevars{i}, 'cell');
                    faceVars{i} = model.discretization.evaluateProp(state, basevars{i}, 'face');
                else
                    % Not dG - repeat to match number of cubature points
                    cellMean{i} = basevars{i};
                    cellVars{i} = basevars{i}(state.cells);
                    faceVars{i} = basevars{i}(state.fcells);
                end
                else
                    [cellMean{i}, cellVars{i}, faceVars{i}, isDof(i)] = model.evaluateBaseVariable(state, basevars{i}, basenames{i});
                end
            end
            % Let parent model handle initStateAD
            basenames(isDof) = cellfun(@(bn) bn(1:end-3), basenames(isDof), 'UniformOutput', false);
            % Initialize cell mean state
            state = parent.initStateAD(state, cellMean, basenames, baseorigin);
            state = model.evaluateBaseVariables(state);
            % Initialize well state
            state.wellStateDG = parent.initStateAD(state.wellStateDG, cellMean, basenames, baseorigin);
            % Initialize cell state
            parent.G.cells.num = numel(value(cellVars{1}));
            state.cellStateDG = parent.initStateAD(state.cellStateDG, cellVars, basenames, baseorigin);
            % Initialize face state
            parent.G.cells.num = numel(value(faceVars{1}));
            state.faceStateDG = parent.initStateAD(state.faceStateDG, faceVars, basenames, baseorigin);
            if useTotalSaturation
                % Set total saturation as well
                sTdof       = vars{isP};
                state.sTdof = sTdof;
                [meanValue, cellValue, faceValue] = model.evaluateBaseVariable(state, sTdof, 'sTdof');
                state.wellStateDG = model.setProp(state.wellStateDG, 'sT', meanValue);
                state.cellStateDG = model.setProp(state.cellStateDG, 'sT', cellValue);
                state.faceStateDG = model.setProp(state.faceStateDG, 'sT', faceValue);
                state             = model.setProp(state, 'sT', meanValue);
            end
        end
        
        function [meanVal, cellVal, faceVal, isDof] = evaluateBaseVariable(model, state, var, name)
            assert(isfield(state, 'psi_c') && isfield(state, 'psi_c'));
            isDof = false;
            if any(strcmpi(name(1:end-3), model.dgVariables)) && strcmpi(name(end-2:end), 'dof')
                % dG - do evaluation at cubature points
                isDof   = true;
                meanVal = model.discretization.getCellMean(state, var);
                cellVal = model.discretization.evaluateProp(state, var, 'cell');
                faceVal = model.discretization.evaluateProp(state, var, 'face');
            else
                % Not dG - repeat to match number of cubature points
                meanVal = var;
                cellVal = meanVal(state.cells,:);
                faceVal = meanVal(state.fcells,:);
            end
        end
        
        function state = evaluateBaseVariables(model, state)
             
            [cellStateDG, faceStateDG, wellStateDG] = deal(state);
            if ~(isfield(state, 'psi_c') && isfield(state, 'psi_f'))
                % Evaluate basis functions at cubature points
                state = model.discretization.evaluateBasisFunctions(state);
            end
            % Assign type and cells/faces
            cellStateDG.type   = 'cell';
            cellStateDG.cells  = state.cells;
            cellStateDG.fcells = state.fcells;
            cellStateDG.faces  = state.faces;
            wellStateDG.type   = 'cell';
            wellStateDG.cells  = state.cells;
            faceStateDG.type   = 'face';
            faceStateDG.cells  = state.fcells;
            faceStateDG.faces  = state.faces;
            % Evaluate valriables
            names = fieldnames(state);
            for k = 1:numel(names)
                name = names{k};
                [fn , index] = model.getVariableField(name, false);
                if ~isempty(fn) && isa(state.(name), 'double') && ... % Only doubles
                        ~any(strcmpi(name, model.dgVariables))        % ... dG variables set from dofs
                    % ... and only variables of correct dimension
                    n = size(double(state.(fn)),1);
                    if (n ~= model.G.cells.num && n ~= sum(state.nDof))
                        continue
                    else
                        % Evaluate
                        [meanVal, cellVal, faceVal] ...
                            = model.evaluateBaseVariable(state, state.(name)(:,index), name);
                        if strcmpi(name(end-2:end), 'dof')
                            name = name(1:end-3);
                        end
                        % Assign to state
                        cellStateDG = model.setProp(cellStateDG, name, cellVal);
                        wellStateDG = model.setProp(wellStateDG, name, meanVal);
                        faceStateDG = model.setProp(faceStateDG, name, faceVal);
                    end
                end
            end
            % Set flag (compositional models)
            if isfield(faceStateDG, 'flag')
                faceStateDG.flag = faceStateDG.flag(fcells);
            end
            % Store cell/well/face states to state
            state.cellStateDG = cellStateDG;
            state.wellStateDG = wellStateDG;
            state.faceStateDG = faceStateDG;
            
        end
        
        function state = assignCellMean(model, state)
            % Assign cell mean for all dg variables
            names = model.dgVariables;
            for name = names
                if isfield(state, [name{1}, 'dof'])
                    dof = model.getProp(state, [name{1}, 'dof']);
                    v   = model.discretization.getCellMean(state, dof);
                    state.(name{1}) = v;
                end
            end
        end
        
        %-----------------------------------------------------------------%
        function model = validateModel(model, varargin)
            model = validateModel@TransportModel(model, varargin{:});
            model.parentModel.FluxDiscretization = FluxDiscretizationDG(model.parentModel);
            fp = model.parentModel.FlowPropertyFunctions;
            pvt = fp.getRegionPVT(model.parentModel);
            fp = fp.setStateFunction('PoreVolume', MultipliedPoreVolumeDG(model.parentModel, pvt));
            fp = fp.setStateFunction('GravityPermeabilityGradient', GravityPermeabilityGradientDG(model.parentModel));
            model.parentModel.FlowPropertyFunctions = fp;
        end
        
        %-----------------------------------------------------------------%
        function [eqs, names, types, state] = getModelEquations(model, state0, state, dt, drivingForces)
            state0 = model.evaluateBaseVariables(state0);
            pmodel = model.parentModel;
            [acc, flux, cellflux, names, types] = pmodel.FluxDiscretization.componentConservationEquations(pmodel, state, state0, dt);
            state.wellStateDG = rmfield(state.wellStateDG, 'FlowProps');
            state.wellStateDG = rmfield(state.wellStateDG, 'FluxProps');
            src = pmodel.FacilityModel.getComponentSources(state.wellStateDG);
            % Treat source or bc terms
            if ~isempty(drivingForces.bc) || ~isempty(drivingForces.src)
                fluxBC  = model.computeBoundaryConditions(state, state0, dt, drivingForces.bc);
            end
            % Assemble equations and add in sources
            if strcmpi(model.formulation, 'missingPhase')
                % Skip the last phase! Only mass-conservative for
                % incompressible problems
                acc   = acc(1:end-1);
                flux  = flux(1:end-1);
                names = names(1:end-1);
                types = types(1:end-1);
            end
            d        = model.discretization;
            d.nDof   = state.nDof;
            d.dofPos = state.dofPos;
            psi      = d.basis.psi;
            gradPsi  = d.basis.gradPsi;
            ixw      = d.getDofIx(state, 1, src.cells);
            ix       = d.getDofIx(state, Inf);
            d.sample = state.cellStateDG.s{1}(ix)*0;
            eqs      = cell(1, numel(acc));
            state.wellStateDG.cells = (1:pmodel.G.cells.num)';
            
            cells  = rldecode((1:pmodel.G.cells.num)', state.nDof, 1);
            pv     = pmodel.operators.pv(cells);
            rhoS   = pmodel.getSurfaceDensities();
            cnames = pmodel.getComponentNames();
            
            for i = 1:numel(acc)
                eqs{i} = d.inner(acc{i}     , psi    , 'dV') ...
                       - d.inner(cellflux{i}, gradPsi, 'dV') ...
                       + d.inner(flux{i}    , psi    , 'dS');
                if ~isempty(drivingForces.bc)
                    eqs{i} = eqs{i} + d.inner(fluxBC{i}, psi, 'dS', drivingForces.bc.face);
                end
                if ~isempty(src.cells)
                    eqs{i}(ixw) = eqs{i}(ixw) - src.value{i};
                end
                if ~pmodel.useCNVConvergence
                    sub = strcmpi(names{i}, cnames);
                    eqs{i} = eqs{i}.*(dt./(pv.*rhoS(sub)));
                end
            end
        end
        
        %-----------------------------------------------------------------%
        function q = computeBoundaryConditions(model, state, state0, dt, bc)
            
            bcState = model.parentModel.FluxDiscretization.buildFlowState(model, state, state0, dt);
            faces = bc.face;
            [~, x, ~, fNo] = model.discretization.getCubature(faces, 'face');
            cNo = sum(model.parentModel.G.faces.neighbors(fNo,:),2);
            names = fieldnames(bcState);
            for k = 1:numel(names)
                name = names{k};
                if numel(name) > 3 && strcmp(name(end-2:end), 'dof')
                    % Get dofs
                    dof = model.getProp(bcState, name);
                    if iscell(dof)
                        v = cell(1,numel(dof));
                        for i = 1:numel(dof)
                            v{i} = model.discretization.evaluateDGVariable(x, cNo, state, dof{i});
                        end
                    else
                        v = model.discretization.evaluateDGVariable(x, cNo, state, dof);
                    end
                    n = name(1:end-3);
                    % Evaluate at boundary face cubature points
                    bcState = model.setProp(bcState, n, v);
                end
            end
            bcState.cells = sum(model.G.faces.neighbors(fNo,:), 2);
            bcState.faces = fNo;
            
            q = computeBoundaryFluxesDG(model.parentModel, bcState, bc);
            
        end
        
        %-----------------------------------------------------------------%
        function [model, state] = prepareTimestep(model, state, state0, dt, drivingForces)
            [model, state] = prepareTimestep@TransportModel(model, state, state0, dt, drivingForces);
            state = assignDofFromState(model.discretization, state, {'pressure'});
        end
        
        %-----------------------------------------------------------------%
        function [restVars, satVars, wellVars] = splitPrimaryVariables(model, vars)
            vars = cellfun(@(n) n(1:end-3), vars, 'UniformOutput', false);
            [restVars, satVars, wellVars] = model.parentModel.splitPrimaryVariables(vars);
            restVars = cellfun(@(n) [n, 'dof'], restVars, 'UniformOutput', false);
            satVars = cellfun(@(n) [n, 'dof'], satVars, 'UniformOutput', false);
        end
        
        %-----------------------------------------------------------------%
        function [state, report] = updateState(model, state, problem, dx, drivingForces)  
            % Remove DG states
            state = rmfield(state, 'cellStateDG');
            state = rmfield(state, 'faceStateDG');
            state = rmfield(state, 'wellStateDG');
            % Store state before update
            state0 = state;
            [restVars, satVars] = model.splitPrimaryVariables(problem.primaryVariables);
            % Update saturation dofs
            state = model.updateSaturations(state, dx, problem, satVars);
            % Update non-saturation dofs
            state = model.updateDofs(state, dx, problem, restVars);
            % Update cell averages from dofs
            state = model.assignCellMean(state);
            % Compute dx for cell averages
            dx0 = model.getMeanIncrement(state, state0, problem.primaryVariables);
            % Let parent model do its thing
            problem0 = problem;
            problem0.primaryVariables = cellfun(@(n) n(1:end-3), problem0.primaryVariables, 'UniformOutput', false);
            [state0_corr, report] = updateState@TransportModel(model, state0, problem0, dx0, drivingForces);
            % Correct updates in dofs according to parent model
            dx0_corr = model.getMeanIncrement(state0_corr, state0, problem.primaryVariables);
            cells    = rldecode((1:model.G.cells.num)', state.nDof, 1);
            frac     = cellfun(@(x,y) x(cells)./y(cells), dx0_corr, dx0, 'UniformOutput', false);
            for i = 1:numel(frac)
                frac{i}(~isfinite((frac{i}))) = 1;
            end
            dx_corr  = cellfun(@(dx, f) dx.*f, dx, frac, 'UniformOutput', false);
            % Update saturation dofs
            state = model.updateSaturations(state0, dx_corr, problem, satVars);
            % Update non-saturation dofs
            state = model.updateDofs(state, dx_corr, problem, restVars);
            % Update cell averages from dofs
            state = model.assignCellMean(state);
        end
        
        %-----------------------------------------------------------------%
        function dx = getMeanIncrement(model, state, state0, vars)
            % Get the increment in the mean value of a set of variables
            dx = cell(numel(vars),1);
            for i = 1:numel(vars)
                vn    = vars{i}(1:end-3);
                v     = model.getProp(state, vn);
                v0    = model.getProp(state0, vn);
                dx{i} = v - v0;
            end
        end
        
        % ----------------------------------------------------------------%
        function state = updateDofs(model, state, dx, problem, dofVars, dvMaxAbs)
            
            for i = 1:numel(dofVars)
                dvMaxAbs = inf;
                if strcmpi(dofVars{i}, 'sTdof') && 0
                    dvMaxAbs = 0.2;
                end
                state = updateStateFromIncrement(model, state, dx, problem, dofVars{i}, inf, dvMaxAbs);
            end
            
        end
        
        % ----------------------------------------------------------------%
        function state = updateSaturations(model, state, dx, problem, satVars)

            if nargin < 5
                % Get the saturation names directly from the problem
                [~, satVars] = ...
                    splitPrimaryVariables(model, problem.primaryVariables);
            end
            if isempty(satVars)
                % No saturations passed, nothing to do here.
                return
            end
            % Solution variables should be saturations directly, find the
            % missing link
            saturations0 = lower(model.parentModel.getSaturationVarNames);
            saturations  = cellfun(@(n) [n, 'dof'], saturations0, 'uniformOutput', false);
            fillsat = setdiff(saturations, lower(satVars));
            nFill = numel(fillsat);
            assert(nFill == 0 || nFill == 1)
            if nFill == 1
                % Fill component is whichever saturation is assumed to fill
                % up the rest of the pores. This is done by setting that
                % increment equal to the negation of all others so that
                % sum(s) == 0 at end of update
                fillsat = fillsat{1};
                solvedFor = ~strcmpi(saturations, fillsat);
            else
                % All saturations are primary variables. Sum of saturations is
                % assumed to be enforced from the equation setup
                solvedFor = true(numel(saturations), 1);
            end
            ds = zeros(sum(state.nDof), numel(saturations));
            
            tmp = 0;
            ix = model.discretization.getDofIx(state, Inf);
            for phNo = 1:numel(saturations)
                if solvedFor(phNo)
                    v = model.getIncrement(dx, problem, saturations{phNo});
                    ds(ix, phNo) = v;
                    if nFill > 0
                        % Saturations added for active variables must be subtracted
                        % from the last phase
                        tmp = tmp - v;
                    end
                end
            end
            ds(ix, ~solvedFor) = tmp;
            % We update all saturations simultanously, since this does not bias the
            % increment towards one phase in particular.
            if 0
                dsAbsMax = model.parentModel.dsMaxAbs/model.discretization.basis.nDof;
            else
                dsAbsMax = model.parentModel.dsMaxAbs/min(model.discretization.basis.nDof, 4);
            end
            state = model.updateStateFromIncrement(state, ds, problem, 'sdof', Inf, dsAbsMax);
            
        end
        
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            state.FacilityFluxProps = state.wellStateDG.FacilityFluxProps;
            [state, report] = updateAfterConvergence@TransportModel(model, state0, state, dt, drivingForces);
            state = rmfield(state, 'cellStateDG');
            state = rmfield(state, 'faceStateDG');
            state = rmfield(state, 'wellStateDG');
            
            propfn = model.parentModel.getStateFunctionGroupings();
            d = model.discretization;
            d.nDof = state.nDof;
            d.dofPos = state.dofPos;
            ix = d.getDofIx(state, 1, Inf);
            psi    = model.discretization.basis.psi(1);
            d.sample = state.sdof(:,1);
            for i = 1:numel(propfn)
                p = propfn{i};
                struct_name = p.getStateFunctionContainerName();
                names = p.getNamesOfStateFunctions();
                if isfield(state, struct_name)
                    for j = 1:numel(names)
                        name = names{j};
                        if ~isempty(state.(struct_name).(name))
                            v = state.(struct_name).(name);
                            nph = numel(v);
                            for ph = 1:nph
                                v{ph} = d.inner(v{ph}, psi, 'dV');
                                v{ph} = v{ph}(ix);
                            end
                            state.(struct_name).(name) = v;
                        end
                    end
                end
            end
            
            if ~isempty(model.limiters)
                
                if model.storeUnlimited
                    state.ul = state;
                    if isfield(state.ul, 'ul')
                        state.ul = rmfield(state.ul, 'ul');
                    end
                end
                
                for l = 1:numel(model.limiters)
                    limiter = model.limiters(l);
                    for v = 1:numel(limiter.variables)
                        state = limiter.function(state, limiter.variables{v}, limiter.tol, limiter.limits{v});
                    end
                end
                
                if 0
                    if isa(model.parentModel, 'GenericBlackOilModel')
                        if model.parentModel.disgas
                            rsSat = model.parentModel.getProp(state, 'RsMax');
                            rs    = model.getProp(state, 'rs');
                            rsdof = model.getProp(state, 'rsdof');
                            [rsMin, rsMax] = model.discretization.getMinMax(state, rsdof);
                            rsMin(rs > rsSat) = rsSat(rs > rsSat);
                            rsMax(rs < rsSat) = rsSat(rs < rsSat);
                            state = model.discretization.limiter{2}(state, 'rs', [rsMin, rsMax]);
                            state = model.discretization.limiter{1}(state, 'rs');
                        end
                        if model.parentModel.vapoil
                            state = model.discretization.limiter{1}(state, 'rv');
                        end
                    end
                end
            end

        end
        
    end
    
end

function sT = getTotalSaturation(s)
    if iscell(s)
        sT  = 0;
        nph = numel(s);
        for i = 1:nph
            sT = sT + s{i};
        end
    else
        sT = sum(s,2);
    end
end