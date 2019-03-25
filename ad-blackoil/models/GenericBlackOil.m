classdef GenericBlackOil < ThreePhaseBlackOilModel & ExtendedReservoirModel
    properties
        
    end
    
    methods
        function model = GenericBlackOil(G, rock, fluid, varargin)
            model = model@ThreePhaseBlackOilModel(G, rock, fluid, varargin{:});
            model.OutputProperties = {'ComponentTotalMass'};

            nph = model.getNumberOfPhases();
            model.Components = cell(1, nph);
            names = model.getPhaseNames();
            for ph = 1:nph
                switch names(ph)
                    case 'W'
                        c = ImmiscibleComponent('water', ph);
                    case 'O'
                        c = OilComponent('oil', ph);
                    case 'G'
                        c = GasComponent('gas', ph);
                    otherwise
                        error('Unknown phase');
                end
                model.Components{ph} = c;
            end
        end
        
        function [problem, state] = getEquations(model, state0, state, dt, drivingForces, varargin)
            [problem, state] = getEquations@ReservoirModel(model, state0, state, dt, drivingForces, varargin{:});
        end
        
        function [eqs, names, types, state] = getModelEquations(model, state0, state, dt, drivingForces)
            [eqs, flux, names, types] = model.FluxDiscretization.componentConservationEquations(model, state, state0, dt);
            src = model.FacilityModel.getComponentSources(state);
            % Assemble equations and add in sources
            for i = 1:numel(eqs)
                if ~isempty(src.cells)
                    eqs{i}(src.cells) = eqs{i}(src.cells) - src.value{i};
                end
                eqs{i} = model.operators.AccDiv(eqs{i}, flux{i});
            end
            % Get facility equations
            [weqs, wnames, wtypes, state] = model.FacilityModel.getModelEquations(state0, state, dt, drivingForces);
            eqs = [eqs, weqs];
            names = [names, wnames];
            types = [types, wtypes];
        end
        
        function names = getComponentNames(model)
            names = cellfun(@(x) x.name, model.Components, 'UniformOutput', false);
        end
        
        function n = getNumberOfComponents(model)
            n = numel(model.Components);
        end
        
        function n = getNumberOfPhases(model)
            n = model.water + model.oil + model.gas;
        end
        
        function [state, report] = updateState(model, state, problem, dx, forces)
            [state, report] = updateState@ThreePhaseBlackOilModel(model, state, problem, dx, forces);
            if ~isempty(model.FacilityModel)
                state = model.FacilityModel.applyWellLimits(state);
            end
        end
        
        function model = validateModel(model, varargin)
            % Validate model.
            %
            % SEE ALSO:
            %   :meth:`ad_core.models.PhysicalModel.validateModel`
            if isempty(model.FacilityModel) || ~isa(model.FacilityModel, 'ExtendedFacilityModel')
                model.FacilityModel = ExtendedFacilityModel(model);
            end
            model = validateModel@ThreePhaseBlackOilModel(model, varargin{:});
        end
        
        function [state, report] = updateAfterConvergence(model, state0, state, dt, drivingForces)
            [state, report] = updateAfterConvergence@ReservoirModel(model, state0, state, dt, drivingForces);
            if model.outputFluxes
                f = model.getProp(state, 'PhaseFlux');
                nph = numel(f);
                state.flux = zeros(model.G.faces.num, nph);
                state.flux(model.operators.internalConn, :) = [f{:}];
            end
        end
    end
end