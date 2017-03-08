function obj = pressureAtCells(model, states, schedule,cells,pstep, varargin)
% states.pressure is a cell array.
% schedule is only used for time steps.
% penalty is a scalar.
% plim is a cell array.
   opt.ComputePartials = false;
   %opt.cells=[];
   %opt.step=[];
   opt.tStep = [];
   opt = merge_options(opt, varargin{:});
   assert(max(cells)<model.G.cells.num);
   %num_timesteps = numel(schedule.step.val);
   tSteps = opt.tStep;
   if isempty(tSteps)
      numSteps = numel(states);
      tSteps = (1:numSteps)';
      %dts = schedule.step.val;
   else
      assert(numel(tSteps) == 1);
      numSteps = 1;
      %dts = schedule.step.val(opt.tStep);
   end
   
   obj = repmat({[]}, numSteps, 1);
   
   for step = 1:numSteps  
        state = states{tSteps(step)}; %@@ +1?      
        p = state.pressure;
        % keep track of amount over or amount under plim at each time step
        if opt.ComputePartials
            sG = state.s(:,2);   % place holders
            sGmax = state.sGmax; % place holders
            nW = numel(schedule.control(1).W);
            pBHP = zeros(nW, 1); % place holders
            qGs = pBHP;          % place holders
            qWs = pBHP;          % place holders
            [p, ~, ~, ~, ~, ~] = initVariablesADI(p, sG, sGmax, qWs, qGs, pBHP); 
        end         
      obj{step}=double(tSteps(step)==pstep)*p(cells);
   end
end