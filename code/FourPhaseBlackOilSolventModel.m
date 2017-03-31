classdef FourPhaseBlackOilSolventModel < ThreePhaseBlackOilModel
    
    properties
        solvent
        
    end
    
    methods
    
        function model = FourPhaseBlackOilSolventModel(G, rock, fluid, varargin)
            
            model = model@ThreePhaseBlackOilModel(G, rock, fluid, varargin{:});
            
            model.solvent = true;
            
            model.saturationVarNames = {'sw', 'so', 'sg', 'ss'};
            model.wellVarNames = {'qWs', 'qOs', 'qGs', 'qSs', 'bhp'};
            
            model = merge_options(model, varargin{:});
            
        end
        
        function [problem, state] = getEquations(model, state0, state, ...
                                               dt, drivingForces, varargin)
                                           
            [problem, state] = equationsThreePhaseBlackOilSolvent(state0, state, ...
                                    model, dt, drivingForces, varargin{:});
            
        end
        
        function state = validateState(model, state)
            state = validateState@ThreePhaseBlackOilModel(mode, state, problem, dx, drivingForces);
            
            model.checkProperty(state, 'Solvent', [model.G.cells.num, 1], [1,2]);
        end
        
        function [state, report] = updateState(model, state, problem, dx, drivingForces)
            [state, report] = updateState@ThreePhaseBlackOilModel(model, ...
               state, problem,  dx, drivingForces);

        end

        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            [state, report] = updateAfterConvergence@ThreePhaseBlackOilModel(model, state0, state, dt, drivingForces);
%             if model.polymer
%                 c     = model.getProp(state, 'polymer');
%                 cmax  = model.getProp(state, 'polymermax');
%                 state = model.setProp(state, 'polymermax', max(cmax, c));
%             end
        end
        
        function [fn, index] = getVariableField(model, name)
            % Get the index/name mapping for the model (such as where
            % pressure or water saturation is located in state)
            switch(lower(name))
                case {'solvent'}
                    index = 4;
                    fn = 'sS';
                otherwise
                    [fn, index] = getVariableField@ThreePhaseBlackOilModel(...
                                    model, name);
            end
        end
        
        function scaling = getScalingFactorsCPR(model, problem, names)
            nNames = numel(names);

            scaling = cell(nNames, 1);
            handled = false(nNames, 1);

            for iter = 1:nNames
                name = lower(names{iter});
                switch name
                    case 'polymer'
                        s = 0;
                    otherwise
                        continue
                end
                sub = strcmpi(problem.equationNames, name);

                scaling{iter} = s;
                handled(sub) = true;
            end
            if ~all(handled)
                % Get rest of scaling factors
                other = getScalingFactorsCPR@ThreePhaseBlackOilModel(model, problem, names(~handled));
                [scaling{~handled}] = other{:};
            end
        end

        
    end
    
end
    