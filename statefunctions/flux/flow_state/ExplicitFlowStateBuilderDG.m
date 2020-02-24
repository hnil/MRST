classdef ExplicitFlowStateBuilderDG < ExplicitFlowStateBuilder & FlowStateBuilderDG
    methods
        function flowState = build(builder, fd, model, state, state0, dt, type)
            % Hybridize state. The base state is the implicit. Other
            % functions are then assigned.
            flowState = build@FlowStateBuilderDG(builder, fd, model, state, state0, dt, type);
            switch type
                case 'face'
                    flowState0 = state0.faceStateDG;
                case 'cell'
                    flowState0 = state0.faceStateDG;
            end
            flowState = build@ExplicitFlowStateBuilder(builder, fd, model, flowState, flowState0, dt);
        end
    end
end
