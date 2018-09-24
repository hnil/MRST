classdef TransportBlackOilModelDG < TransportBlackOilModel
    % Two phase oil/water system without dissolution with discontinuous
    % Galerking discretization
    
    properties
        disc % DG discretization
    end

    methods
        function model = TransportBlackOilModelDG(G, rock, fluid, varargin)s
            
            model = model@TransportBlackOilModel(G, rock, fluid);
            model.disc = [];
            % If we use reordering, this tells us which cells are actually
            % part of the discretization, and which cells that are included
            % to get fluxes correct
            model.G.cells.ghost = false(G.cells.num,1);
            model = merge_options(model, varargin{:});
            
            % Construct discretization
            if isempty(model.disc)
                model.disc = DGDiscretization(model, G.griddim);
            end

        end

        % ----------------------------------------------------------------%
        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)
            [problem, state] ...
                = transportEquationOilWaterDG(state0, state, model, dt, drivingForces, ...
                                  'solveForOil'  , model.conserveOil  , ...
                                  'solveForWater', model.conserveWater, ...
                                  'solveForGas'  , model.conserveGas  , ...
                                  varargin{:}                         );
            
        end
        
        % ----------------------------------------------------------------%
        function [fn, index] = getVariableField(model, name)
            % Map variables to state field.
            %
            % SEE ALSO:
            %   :meth:`ad_core.models.PhysicalModel.getVariableField`
            switch(lower(name))
                case {'water', 'swdof'}
                    index = 1;
                    fn = 'sdof';
                case {'oil', 'sodof'}
                    index = 2;
                    fn = 'sdof';
                case {'gas', 'sgdof'}
                    index = 3;
                    fn = 'sdof';
                case{'saturation', 'sdof'}
                    index = ':';
                    fn = 'sdof';
                otherwise
                    % This will throw an error for us
                    [fn, index] = getVariableField@TransportOilWaterModel(model, name);
            end
        end

        % ----------------------------------------------------------------%
        function vars = getSaturationVarNames(model)
            vars = {'sWdof', 'sOdof', 'sGdof'};
            ph = model.getActivePhases();
            vars = vars(ph);
        end
        
        %-----------------------------------------------------------------%
        function integrand = cellIntegrand(model, x, cellNo, f, sdof, sdof0, state, state0)
            
            % Evaluate saturations and fractional flow at cubature points
            s  = model.disc.evaluateSaturation(x, cellNo, sdof , state );
            s0 = model.disc.evaluateSaturation(x, cellNo, sdof0, state0);
            f = f(s, 1-s, cellNo, cellNo);
            integrand = @(psi, grad_psi) fun(s, s0, f, cellNo, psi, grad_psi);
            
        end
        
        %-----------------------------------------------------------------%
        function integrand = faceIntegrand(model, fun)
            
        end
        
        % ----------------------------------------------------------------%
        function state = updateSaturations(model, state, dx, problem, satVars)
            % Update of phase-saturations
            %
            % SYNOPSIS:
            %   state = model.updateSaturations(state, dx, problem, satVars)
            %
            % DESCRIPTION:
            %   Update saturations (likely state.s) under the constraint that
            %   the sum of volume fractions is always equal to 1. This
            %   assumes that we have solved for n - 1 phases when n phases
            %   are present.
            %
            % PARAMETERS:
            %   model   - Class instance
            %   state   - State to be updated
            %   dx      - Cell array of increments, some of which correspond 
            %             to saturations
            %   problem - `LinearizedProblemAD` class instance from which `dx`
            %             was obtained.
            %   satVars - Cell array with the names of the saturation
            %             variables.
            %
            % RETURNS:
            %   state - Updated state with saturations within physical
            %           constraints.
            %
            % SEE ALSO:
            %   `splitPrimaryVariables`

            if nargin < 5
                % Get the saturation names directly from the problem
                [~, satVars] = ...
                    splitPrimaryVariables(model, problem.primaryVariables);
            end
            if isempty(satVars)
                % No saturations passed, nothing to do here.
                return
            end
            % Solution variables should be saturations directly, find the missing
            % link
            saturations = lower(model.getSaturationVarNames);
            fillsat = setdiff(saturations, lower(satVars));
            assert(numel(fillsat) == 1)
            fillsat = fillsat{1};

            % Fill component is whichever saturation is assumed to fill up the rest of
            % the pores. This is done by setting that increment equal to the
            % negation of all others so that sum(s) == 0 at end of update
            solvedFor = ~strcmpi(saturations, fillsat);
%             ds = zeros(sum(model.disc.nDof), numel(saturations));
            ds = zeros(sum(state.nDof), numel(saturations));
            
            tmp = 0;
            active = ~model.G.cells.ghost;
            ix = model.disc.getDofIx(state, [], active);
            for i = 1:numel(saturations)
                if solvedFor(i)
                    v = model.getIncrement(dx, problem, saturations{i});
                    ds(ix, i) = v;
                    % Saturations added for active variables must be subtracted
                    % from the last phase
                    tmp = tmp - v;
                end
            end
            ds(ix, ~solvedFor) = tmp;
            % We update all saturations simultanously, since this does not bias the
            % increment towards one phase in particular.
%             state = model.updateStateFromIncrement(state, ds, problem, 'sdof', inf, inf);
            state = model.updateStateFromIncrement(state, ds, problem, 'sdof', inf, model.dsMaxAbs);
            
            
            
%             state = model.updateStateFromIncrement(state, ds, problem, 'sdof', inf, inf);
            state = model.disc.getCellSaturation(state);
            
            if model.disc.degree > 0 && 1
                
                state = model.disc.limiter(state);
                state = model.disc.updateDofPos(state);
                
                
                  
%             sWdof = model.disc.limiter(state.sdof(:,1));
%             sOdof = -sWdof;
%             ix = 1:model.disc.basis.nDof:model.G.cells.num*model.disc.basis.nDof;
%             sOdof(ix) = 1 - sWdof(ix);
% 
%             state.sdof = [sWdof, sOdof];

%                 state = model.disc.getCellSaturation(state);

            elseif 1
                
                bad = any(state.s < 0 | state.s > 1,2);
    %                         sdof(ix,:) = min(max(sdof(ix,:), 0), 1);
                state.sdof(bad,:) = min(max(state.sdof(bad,:), 0), 1);
                state.sdof(bad,:) = state.sdof(bad,:)./sum(state.sdof(bad,:),2);
                state.s(bad,:) = state.sdof(bad,:);
%                 ix = disc.getDofIx(state, 2:nDofMax, bad);
            end
            
        end
        %{
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            % Generic update function for reservoir models containing wells.
            %
            % SEE ALSO:
            %   :meth:`ad_core.models.PhysicalModel.updateAfterConvergence`

            [state, report] = updateAfterConvergence@TransportOilWaterModel(model, state0, state, dt, drivingForces);
            
            state = model.disc.limiter(state);
            state = model.disc.updateDofPos(state);
            state.nDof = model.disc.getnDof(state);
            
%             if model.disc.degree > 0 & 1
% 
%             sWdof = model.disc.limiter(state.sdof(:,1));
%             sOdof = -sWdof;
%             ix = 1:model.disc.basis.nDof:model.G.cells.num*model.disc.basis.nDof;
%             sOdof(ix) = 1 - sWdof(ix);
% 
%             state.sdof = [sWdof, sOdof];
% 
%             state = model.disc.getCellSaturation(state);
    
        end
        %}
        
    end
end

%{
Copyright 2009-2017 SINTEF ICT, Applied Mathematics.

This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

MRST is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MRST is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MRST.  If not, see <http://www.gnu.org/licenses/>.
%}