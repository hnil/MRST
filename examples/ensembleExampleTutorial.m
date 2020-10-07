mrstModule add ad-core ad-props ad-blackoil example-suite ensemble ...
    mrst-gui co2store
mrstVerbose on

%%
example = MRSTExample('qfs_wo');

%% Generate an ensemble
% The stochastic component (or uncertain parameter) of any ensemble
% simulation is implemented in a sample class, and a specific realization
% of is referred to as a sample. We can set up a sample class in three
% different ways, by providing
% 1) a function that generates a stochastic sample;
% 2) a cell array of precomputed samples;
% 3) an instance of ResultHandler that points to a location where
%    precomputed samples are stored.
% We will show you all three possibilities in this exmaple.

%% Using a generator function
% We will use the function 'generateRockSample', which generates rock
% samples based on a stationary Gaussian process on the [0,1]^d box [1].
% Inputs to the generator function in the sample class should be the
% problem setup and seed for controlling the random number generator, so we
% make a functio n handle taking in these arguments.
generatorFn = @(problem, seed) ...
    generateRockSample(problem.model.G.cartDims, 'seed', seed);
% The class RockSamples implements routines for getting stochastic rock
% realizations, and setting the to the model. The latter also includes
% updating all model operators depending on the rock.
samplesFn = RockSamples('generatorFn', generatorFn);
% Notice that the data property of samplesFn is empty, the
% generatorFn property in non-empy, whereas the num propery says inf. The
% latter refers to the number of samples, and is inf since we in principle
% can generate as many samples as we want.
disp(samplesFn);

%% Using a cell array of precomputed samples
% To illustrate how we can use precomputed rock samples, we use the same
% function to generate an ensemble of 200 realizations.
ensembleSize = 50;
data         = cell(ensembleSize, 1);
for i = 1:ensembleSize
    data{i} = generateRockSample(example.model.G.cartDims, 'seed', i);
end
samplesCell = RockSamples('data', data);
% This time, the 'generatorFn' property is empty, whereas the 'data'
% property is a cell array of the 50 realizations we just made. Note also
% that the 'num' property says 50.
disp(samplesCell);

%% Using a ResultHandler
% The problem size is very often so large that holding all ensemble members
% in memory is intractable. In cases when we have a set of samples that are
% stored to file, we can provide a ResultHandler to the RockSample class
% that facilitates loading the samples from disk.
dataDir = fullfile(mrstOutputDirectory(), 'ensemble', 'tutorial');
if ~exist(dataDir, 'dir'), mkdir(dataDir); end
rh = ResultHandler('dataDirectory', dataDir  , ... % Example root folder
                   'dataFolder'   , 'samples', ... % Sample folder
                   'dataPrefix'   , 'sample_');    % samples_<seed>.mat
rh(1:ensembleSize) = data;           % Store samples
samplesRH = RockSamples('data', rh); % Set up rock samples
% As in the previous case, the 'generatorFn' property is empty and the
% 'num' property says 50, but the 'data' property is now the ResultHandler
% we just created.
disp(samplesRH);

%% Quantity of interest
% The quantity that we are interested in from an ensemble simulation is
% called quantity of interest (QoI). In this example, we will look at two
% QoIs: the water saturation after 200 days of injection, and the water cut
% in the producer over the entire simulation.

%% Reservoir state QoIs
% All QoIs derived from the reservoir state (except wells) are implemented
% in ReservoirStateQoI. The 'property' input refers to the namy of a
% property that can be fetched or computed from the state using
% model.getProp, whereas the 'time' input is the time at which we want the
% quantity. The may be a vector, and for each element, the class will pick
% the timestep correponding to the closest timestamp.
qoiState = ReservoirStateQoI('name', 'sW', 'time', [20, 200, 700]*day);
disp(qoiState);

%% Well output QoIs
% All QoIs related to well output are implemented in WellOutputQoI. This
% class the function getWellOutput to get the results from the well
% solutions, and therefore has properties inputs of this function:
% 'fldnames' is field name of interest stored on wellSol, whereas 'wellIndices'
% is a vector with the well number(s). An alternative to 'wellIndices' is to 
% provide 'wellNames' instead as a cell array of well names.
qoiWell = WellQoI('fldname', 'qOs', 'wellIndices', 2);
disp(qoiWell);

%% Running a single sample
% We have now defined all ingredients necessary to set up an instance of
% the ensemble class. First, however, we set up and simulate a single
% sample to illustrate the different steps.
problem = example.getPackedSimulationProblem(); % Get packed problem
data    = samplesCell.getSample(13, problem);   % Get sample numer 13
% Like the rock structure of a model, the sample has a perm and poro field
disp(data);
problem = samplesCell.setSample(data, problem);  % Set sample to problem
% Inspect rock sample
example.plot(problem.SimulatorSetup.model.rock, 'log10', true); colormap(pink);
simulatePackedProblem(problem); % Simulate

% To inspect the quantities of interest directly, we first need to
% match the configurations of the QoI objects with the configurations of
% the problem at hand. Note that this step is done automatically within the 
% MRSTEnsemble class.
qoiStateValidated = qoiState.validateQoI(problem);
qoiWellValidated  = qoiWell.validateQoI(problem);
disp(qoiStateValidated);
disp(qoiWellValidated);

% Quantities of interest are computed from the problem
sat = qoiStateValidated.computeQoI(problem); % Water saturation after 200 days
qOs = qoiWellValidated.computeQoI(problem);  % Producer water cut

%% Plot the results
close all
example.plot(sat); colormap(bone);
time = cumsum(example.schedule.step.val)/day;
figure(), plot(time, qOs*day, 'LineWidth', 1.5); % Convert to days
xlim([0, time(end)]), box on, grid on, xlabel('Time (days)');

%% Set up the ensemble
% The MRSTEnsemble class conveniently gathers the problem setup, the
% samples and the QoI, and implements the functionality for everything
% related to setting up and simulating an ensemble member and computing the
% corresponding QoI. The first input parameter can either be an already set
% up MRSTExample, or the name of an MRSTExample function. In the latter
% case, MRSTEnsemble will first set up the example, and optional input
% arguments to the example can be passed just as in the MRSTExample class.
ensemble = MRSTEnsemble(example, samplesRH, qoiState);

%% Simulate the ensemble
ensemble.simulateEnsembleMembers(1:ensembleSize);

%% Plot results
close all
[x,y] = ndgrid(linspace(0,1000, example.options.ncells));
s_avg = 0;
for i = 1:ensembleSize
    s = ensemble.qoi.ResultHandler{i}{2};
    if rem(i, 10) == 0, example.plot(s); colormap(bone); caxis([0,1]); end
    s_avg = (s_avg.*(i-1) + s)./i;
end
example.plot(s_avg); colormap(bone);  caxis([0,1]);