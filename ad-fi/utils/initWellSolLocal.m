function wellSol = initWellSolLocal(W, state0, wellSolInit)
% model = someFunction(state)
% initialization should depend on model, for now just dstinguish between 2
% and three phases
wellSolGiven =  (nargin == 3);

if size(state0.s, 2) == 2
    model = 'OW';
else
    model = '3P';
end

if wellSolGiven
    wellSol = wellSolInit;
elseif isfield(state0, 'wellSol')
    wellSol = state0.wellSol;
else
    wellSol = defaultWellSol(state0, W, model);
end
wellSol = assignFromSchedule(W, wellSol);
end

function ws = defaultWellSol(state, W, model)
nw = numel(W);
if strcmp(model, 'OW')
    actPh = [1,2];
else
    actPh = [1,2,3];
end
ws = repmat(struct(...
    'name',   [],...
    'status', [],...
    'type',   [],...
    'val',    [],...
    'sign',   [],...
    'bhp',    [],...
    'qTs',    [],...
    'qWs',    [],...
    'qOs',    [],...
    'qGs',    [],...
    'mixs',   [],...
    'cstatus',[],...
    'cdp',    [],...
    'cqs',    []), [1, nw]);
% additional fields depending on model
% just initialize fields that are not assigned in assignFromSchedule
for k = 1:nw
    nConn = numel(W(k).cells);
    nPh   = numel(actPh);
    ws(k).name = W(k).name;
    % To avoid switching off wells, we need to start with a bhp that makes
    % a producer produce and an injector inject. Hence, we intitialize the
    % bhp such that the top connection pressure is 5bar above/below the
    % corresponding well-cell pressure. If W(k).dZ is ~= 0, however, we
    % don't know wht a decent pressure is ...
    % The increment should depend on the problem and the 5bar could be a
    % pit-fall... (also used in initializeBHP in updateConnDP)
    %if W(k).dZ(1) == 0
        ws(k).bhp = state.pressure(W(k).cells(1)) + 5*W(k).sign*barsa;
    %else
    %    ws(k).bhp = -inf;
    %end
    ws(k).qTs  = 0;
    ws(k).qWs  = 0;
    ws(k).qOs  = 0;
    ws(k).qGs  = 0;
    ws(k).mixs = W(k).compi(actPh);
    ws(k).qs   = zeros(1, nPh);
    ws(k).cdp  = zeros(nConn,1);
    ws(k).cqs  = zeros(nConn,nPh);
end
end

function ws = assignFromSchedule(W, ws)
% set fields that should be updated if control has changed
for k = 1:numel(W)
    ws(k).status  = W(k).status;
    ws(k).type    = W(k).type;
    ws(k).val     = W(k).val;
    ws(k).sign    = W(k).sign;
    ws(k).cstatus = W(k).cstatus;

    tp = W(k).type;
    if ws(k).status
        v  = W(k).val;
    else
        v = 0;
        ws(k).bhp = 0;
        ws(k).val = 0;
    end
    switch tp
        case 'bhp'
            ws(k).bhp = v;
        case 'rate'
            ws(k).qWs = v*W(k).compi(1);
            ws(k).qOs = v*W(k).compi(2);
            ws(k).qGs = v*W(k).compi(3);
        case 'orat'
            ws(k).qOs = v;
        case 'wrat'
            ws(k).qWs = v;
        case 'grat'
            ws(k).qGs = v;
    end % No good guess for qOs, etc...
end
end

