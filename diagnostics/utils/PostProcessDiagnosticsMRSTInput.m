function [d] = PostProcessDiagnosticsMRSTInput(problem,varargin)

opt = struct('style', 'default', ...
    'steps',        [], ...
    'maxTOF', 500*year, ...
    'cleanup',   false, ...
    'precompute', true);
mrstModule add mrst-gui diagnostics deckformat ad-props coarsegrid
mrstVerbose(true)

opt = merge_options(opt, varargin{:});
pth = problem.OutputHandlers.states.getDataPath();

% precompute options
precompDir = fullfile(pth, 'mrst_diagnostics');
if opt.cleanup
    cleanupDialogue(precompDir);
end


if opt.precompute
    dd = dir(precompDir);
    %if exist(precompDir,'dir')~=7
    %    mkdir(precompDir);
    %end
    % only precompute if directory is empty or non-existent
    if ~any(~strncmp({dd.name}, '.', 1))
        precomputeDialogue(problem, precompDir);
    end
end




% Select which time-steps to include
rsspec = processEclipseRestartSpec(casenm, 'all');
if ~isempty(opt.steps)
    steps = opt.steps;
else
    steps = uiPreSelectTimeSteps(rsspec);
end

% Setup data for selected steps and load/compute diagnostics
d.maxTOF = opt.maxTOF;
if opt.precompute
    precomp = getPrecomputedDiagnostics(casenm, steps);
else
    precomp = [];
end
[d.G, d.Data, d.Gs, valid_ix] = readAndPrepareForPostProcessor(casenm, steps, rsspec, precomp);
if ~any(valid_ix)
    return;
end
if ~all(valid_ix) && ~isempty(precomp)
    precomp = precomp(valid_ix);
end

try
    d.Data.summary = readEclipseSummaryUnFmt(casenm);
catch
    d.Data.summary = [];
    warning('Not able to read summary for selected case ...\n')
end

d = PostProcessDiagnostics(d,precomp,'style',opt.style);

