function [ws, states, reports] = getPackedSimulatorOutput(problem, varargin)
    opt = struct('readFromDisk', true);
    opt = merge_options(opt, varargin{:});
    
    nstep = numel(problem.SimulatorSetup.schedule.step.val);
    
    sh = problem.OutputHandlers.states;
    rh = problem.OutputHandlers.reports;
    
    ndata = sh.numelData();
    [ws, states, reports] = deal(cell(ndata, 1));
    wantWells = false;
    for i = 1:numel(problem.SimulatorSetup.schedule.control)
        ctrl = problem.SimulatorSetup.schedule.control(i);
        if isfield(ctrl, 'W') && ~isempty(ctrl.W)
            wantWells = true;
            break
        end
    end
    statesInMemory = nargout > 1 && opt.readFromDisk;

    sn = sprintf('%s (%s)', problem.BaseName, problem.Name);
    if nstep == ndata
        fprintf('Found complete data for %s: %d steps present\n', sn, ndata);
    elseif ndata > 0
        fprintf('Found partial data for %s: %d of %d steps present\n', sn, ndata, nstep);
    else
        fprintf('Did not find data for %s\n', sn);
    end
    
    for i = 1:ndata
        if wantWells || statesInMemory
            state = sh{i};
            ws{i} = state.wellSol;
        end
        if statesInMemory
            states{i} = state;
        end
        if nargout > 2 && opt.readFromDisk
            reports{i} = rh{i};
        end
    end
    
    if ~opt.readFromDisk
        % Just return handlers instead
        states = sh;
        reports = rh;
    end
end