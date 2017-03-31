classdef OilWaterSolventModel < TwoPhaseOilWaterModel

    properties
        
        solvent
        
    end
    
    methods
        
        function model = OilWaterSolventModel(G, rock, fluid, varargin)
            
            model = model@TwoPhaseOilWaterModel(G, rock, fluid);
            
            % This is the model parameters for oil/water/polymer
            model.solvent = true;
            model.saturationVarNames = {'sw', 'so', 'ss'};
            
            model = merge_options(model, varargin{:});
            
        end
        
        function [problem, state] = getEquations(model, state0, state, ...
                dt, drivingForces, varargin)
            [problem, state] = equationsOilWaterSolvent(state0, state, ...
                model, dt, drivingForces, varargin{:});
        end
        
        function state = validateState(model, state)
            state = validateState@TwoPhaseOilWaterModel(model, state);
            % Polymer must be present
            model.checkProperty(state, 'Solvent', model.G.cells.num, 1);
        end

        function [state, report] = updateState(model, state, problem, ...
                dx, drivingForces)
            [state, report] = updateState@TwoPhaseOilWaterModel(model, ...
               state, problem,  dx, drivingForces);
            
%             if model.polymer
%                 c = model.getProp(state, 'polymer');
%                 c = min(c, model.fluid.cmax);
%                 state = model.setProp(state, 'polymer', max(c, 0) );
%             end
        end
        
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            [state, report] = updateAfterConvergence@TwoPhaseOilWaterModel(model, state0, state, dt, drivingForces);
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
                    index = 3;
                    fn = 's';
                otherwise
                    [fn, index] = getVariableField@TwoPhaseOilWaterModel(...
                                    model, name);
            end
        end
        function names = getComponentNames(model)
            names = getComponentNames@TwoPhaseOilWaterModel(model);
            if model.solvent
                names{end+1} = 'solvent';
            end
        end

        function scaling = getScalingFactorsCPR(model, problem, names)
            nNames = numel(names);

            scaling = cell(nNames, 1);
            handled = false(nNames, 1);

            for iter = 1:nNames
                name = lower(names{iter});
%                 switch name
%                     case 'polymer'
%                         s = 0;
%                     otherwise
%                         continue
%                 end
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
