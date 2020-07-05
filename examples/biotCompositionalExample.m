% Load modules

mrstModule add ad-core ad-blackoil compositional ad-props mrst-gui mpsaw mpfa

clear all
% close all


%% Setup geometry

dims = [30, 30];
% dims = [2, 2];
G = cartGrid(dims, [2, 1]);
makeSkew = @(c) c(:,1) + .4*(1-(c(:,1)-1).^2).*(1-c(:,2));
G.nodes.coords(:,1) = 2*makeSkew(G.nodes.coords);
G.nodes.coords(:, 1) = G.nodes.coords(:, 1);
G.nodes.coords(:, 2) = G.nodes.coords(:, 2);

G = computeGeometry(G);

%% Homogeneous reservoir properties
alpha = 1; % biot's coefficient

rock = makeRock(G, 1, 1);
rock.alpha = alpha*ones(G.cells.num, 1);
pv = sum(poreVolume(G, rock));

%% setup fluid and wells 

pRef = 0*barsa;
gravity reset off;
fluid = initSimpleADIFluid('cR', 1, 'pRef', pRef, 'rho', [1, 1000, 100]);

% Symmetric well pattern
[ii, jj] = gridLogicalIndices(G);

% Injector + two producers
W = [];
W = addWell(W, G, rock, find(ii == ceil(G.cartDims(1)/2) & jj == G.cartDims(2)), 'radius', 1e-3, 'comp_i', [1, 0], 'type', 'rate', 'val', pv);
W = addWell(W, G, rock, find(ii == G.cartDims(1) & jj == 1), 'radius', 1e-3, 'comp_i', [1, 0], 'type', 'bhp', 'val', pRef);
W = addWell(W, G, rock, find(ii == 1 & jj == 1), 'radius', 1e-3, 'comp_i', [1, 0], 'type', 'bhp', 'val', pRef);


[f, info] = getCompositionalFluidCase('verysimple');
eos = EquationOfStateModel(G, f);

for i = 1:numel(W)
    W(i).components = info.injection;
end
z0 = info.initial;
state0 = initCompositionalState(G, info.pressure, info.temp, [1, 0], z0, eos);
W(1).val = 100*W(1).val;

%% setup mechanics mech structure (with field prop and loadstruct)

lambda    = 0;
mu        = 1;
top_force = 1;

lambda = lambda*ones(G.cells.num, 1);
mu = mu*ones(G.cells.num, 1);
mechprop = struct('lambda', lambda, 'mu', mu);

[tbls, mappings] = setupStandardTables(G);

% We set zero displacement at all external faces

extfaces = find(any(G.faces.neighbors == 0, 2));
nextf = numel(extfaces);
extfaces = rldecode(extfaces, 2*ones(nextf, 1));
linform = repmat([[1, 0]; [0, 1]], nextf, 1);
bcvals   = zeros(numel(extfaces), 1);

bc = struct('linform'    , linform , ...
            'extfaces'   , extfaces, ...
            'linformvals', bcvals);

bc = setupFaceBC(bc, G, tbls);

nodefacecoltbl = tbls.nodefacecoltbl;
extforce = zeros(nodefacecoltbl.num, 1);

cellcoltbl = tbls.cellcoltbl;
force = zeros(cellcoltbl.num, 1);

loadstruct.bc = bc;
loadstruct.extforce = extforce;
loadstruct.force = force;

% setup mech structure 
mech.prop = mechprop;
mech.loadstruct = loadstruct;

modelMpfa = BiotCompositionalModel(G, rock, fluid, eos, mech, 'water', false);
modelMpfa.OutputStateFunctions = {'Dilatation', 'Stress'};
% modelTpfa = BiotTpfaBlackOilModel(G, rock, fluid, mech, 'water', true, 'oil', true, 'gas', false);
% modelTpfa.OutputStateFunctions = {'Dilatation', 'Stress'};

mechmodel = MechModel(G, mech);
statemech = mechmodel.solveMechanics();

state0.u = statemech.u;
state0.lambdamech = statemech.lambdamech;
state0.biotpressure = state0.pressure;

dt = 1e-1;
nsteps = 10;
schedule.step.val = dt*ones(nsteps, 1);
schedule.step.control = ones(numel(schedule.step.val), 1);
schedule.control = struct('W', W);

[ws, statesMpfa] = simulateScheduleAD(state0, modelMpfa, schedule);

return

% [wstpfa, statesTpfa] = simulateScheduleAD(state0, modelTpfa, schedule);

%% Reformat stress
for i = 1 : numel(statesMpfa)
    stress = modelMpfa.getProp(statesMpfa{i}, 'Stress');
    stress = formatField(stress, G.griddim, 'stress');
    statesMpfa{i}.stress = stress;
    stress = modelTpfa.getProp(statesTpfa{i}, 'Stress');
    stress = formatField(stress, G.griddim, 'stress');
    statesTpfa{i}.stress = stress;
end

%% plot
figure;
plotToolbar(G, statesMpfa);
title('MPFA')

figure
plotToolbar(G, statesTpfa);
title('TPFA')


