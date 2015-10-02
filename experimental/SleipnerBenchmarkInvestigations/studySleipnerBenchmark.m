%% Sleipner simulation
% The following studies the Sleipner benchmark data set which comes from
% Singh et al 2010 (SPE paper).

% There are several options available to run this benchmark, which are
% explained below:

    % The first option is related to which Sleipner grid is loaded.
    % Currently, this script can handle the IEAGHG model, the ORIGINAL
    % (GHGT) model, and the INHOUSE (Statoil) model. All grids are capable
    % of refinement. TODO: keep names consistent; IEAGHG, ORIGINAL = GHGT
    % (in-house), INHOUSE (Statoil).

    % The second option is which annual injection rates to use. The
    % available rates are either those which come from Singh et al 2010
    % (SPE 134891) (i.e., rates between 1999 and 2009) or those which came
    % with the original Sleipner benchmark files (i.e., rates between 1999
    % and 2030).

    % The third option is whether to modify the rock and/or fluid
    % properties which have been loaded from the model file. Currently,
    % permeability and porosity are modified when "mod_rock=true", and CO2
    % reference density is modified when "mod_rhoCO2=true". The
    % modification factors are user-defined.

    % Other options available in this script coorespond to the typical
    % input parameters that must be defined such as sea floor temperature,
    % time step sizes, migration period, etc.
    
    
% Notes about the files needed to load the specified grid:

    % To use the IEAGHG model, the necessary grdecl files are:
        % M9X1.grdecl, M9X1_perm_X_mD_.inc, M9X1_perm_Y_mD_.inc,
        % M9X1_poro___.inc, SLEIPNER.DATA
    % The above files should be downloaded and placed in:
        % co2lab/data/sleipner/

        
    % To use the ORIGINAL model, the necessary grdecl files are:
        % sleipner_prep.data
    % The above file(s) should be placed in:
        % co2lab/data/sleipner/original/
        
    
    % To use the INHOUSE model, the necessary grdecl file is:
        % M920X1_40DZ.grdecl
    % The above file should be placed in:
        % co2lab/data/sleipner/
    

% Notes about other files needed for this script to run:

    % CO2 plume outlines - "layer9_polygons_XXXX.mat" (where XXXX is the
    % year, such as 1999) files should be created and placed in current
    % working directory.


% Note that the following script will read the appropriate grdecl files and
% make the MRST-type grids (G and Gt). The first time the grids and rock
% data are generated, they are saved to /co2lab/data/mat/ to avoid
% re-generation every time this script is run. Since the grids are in the
% physical coordinate system, the injection location is specified in this
% same coordinate system.

% This script can be used to run an injection scenario as well as perform
% post-processing of the results. To run a new injection scenario, ensure
% performPostProcessing = false. To perform post-processing, ensure results
% of a finished and saved run are successfully loaded into the workspace
% before script execution.

% SEE ALSO:
%   runSleipner, analyseSleipner (co2lab/experimental/project/tests/)

%%

mrstModule add co2lab
moduleCheck('ad-core','opm_gridprocessing','mex','deckformat', ...
    'coarsegrid','upscaling','incomp','mrst-experimental');
mrstVerbose on
gravity on;


% ******************** START OF USER OPTIONS ******************************
% Is this post-processing or a new injection scenario?
performPostProcessing = false;


if ~performPostProcessing
    disp('Starting new injection scenario.')

% selection of what will be plotted before simulation starts:
plotModelGrid                   = false;
plotInitialPressure             = false;
plotActualVsSimInjectLocation   = false;
plotInjectRateOverTime          = false;


% Trapping analysis method (used for Post-processing, not simulation).
isCellBasedMethod = false; % true to use cell-based method, false to use node-based method


% FOR PLOTS:
CO2plumeOutline_SatTol  = (0.01/100); % adjust this value if patch error occurs (which happens when no massCO2 present at specified sat tol)
press_deviation = 0;  % from hydrostatic (percent) --> used for trapping capacity calculation, not simulation


% For plotting of CO2 plumes
% bounds of 2008 plume:
ZoomX1 = 0.4375e6;
ZoomY1 = 6.47e6;
ZoomX2 = 0.4395e6;
ZoomY2 = 6.474e6;


% OPTION - Select the grid model to load/use:
mycase          = 'useOriginal_model';    % 'useIEAGHG_model', 'useOriginal_model', 'useInhouse_model'
myresolution    = 'none';               % 'useRefinedGrid', 'none'
refineLevel     = 2;                    % only used when "myresolution = useRefinedGrid"


% Physical coordinate of injection well (Singh et al. 2010)
wellXcoord      = 4.38516e5;
wellYcoord      = 6.47121e6;


% OPTION - Well injection rate:
myInjRates = 'useRatesFromSPE134891';   % 'useRatesFromSPE134891', 'useSleipnerOriginalInjectionRates'

switch myInjRates
    
    % Note, inj_rates are in terms of reservoir rates (i.e., the volumetric
    % rate of CO2 entering layer 9, not the volumetric surface rate).
    % Seismic imaging provided estimates of how much CO2 accumlated in the
    % pore space of layer 9. These volumes were likely converted into a
    % mass using an infered CO2 density, and then into a surface rate using
    % the CO2 density at the surface. Specifying the inj_rates in terms of
    % reservoir volume instead of surface volume allows one to test other
    % CO2 densities without the need to modify a surface volume injection
    % rate.
    
    case 'useRatesFromSPE134891'
        % See Singh et al 2010 for more info about how they determined
        % these rates. Note: the injection rates were reported as surface
        % rates. Both volume and mass were given, thus surface density can
        % be calculated (=1.87 kg/m3). The CO2 density at reservoir
        % conditions was reported as 760 kg/m3.
        inj_year   = [1999; 2000; 2001; 2002; 2003; 2004; 2005; 2006; 2007; 2008; 2009];
        inj_rates  = [2.91e4; 5.92e4; 6.35e4; 8.0e4; 1.09e5; 1.5e5; 2.03e5; 2.69e5; 3.47e5; 4.37e5; 5.4e5] .* meter^3/day;
        % inj_rates is in meter^3/s
        % Convert to rate at reservoir conditions
        inj_rates  = inj_rates.*(1.87/760);
        
    case 'useSleipnerOriginalInjectionRates'
        % See "Injection rates Layer 9.xls" under
        % co2lab/data/sleipner/original for more info about these rates.
        % Note: the CO2 density at reservoir conditions was reported as
        % 695.89 kg/m3, and the surface density was 1.87 kg/m3.
        [ inj_year, inj_rates ] = getSleipnerOriginalInjectionRates();
        % inj_rates is in meter^3/s
        
    otherwise
        error('The injection rate option was either invalid or not selected.')
        
end

% Plot inj_rates over inj_year. Plotting later occurs using schedule fields
figure
plot(inj_year, inj_rates, 'o')
ylabel('Reservoir rates, m^3/year')
xlabel('Year')


% Specify and compute time step size for injection period.
% ***Note: inj_time and inj_steps are applied to each inj_rate given***
inj_time    = 1 * year; % DEFAULT. CAN ONLY ADJUST NUMBER OF STEPS.
inj_steps   = 1;
dTi         = inj_time / inj_steps; % timestep size in seconds

% Specify and compute time step size for migration period. 
mig_time    = 1 * year; % CAN ADJUST.
mig_steps   = 1;        % CAN ADJUST.
dTm         = mig_time / mig_steps; % timestep size in seconds


% Specify fluid properties:
[rho, mu, sr, sw]   = getValuesSPE134891();
water_density       = rho(1) * kilogram / meter ^3;
rhoCref             = rho(2) * kilogram / meter ^3;

seafloor_temp       = 7; % Celsius
seafloor_depth      = 100; % meters
temp_gradient       = 35.6; % Celsius / km
water_compr_val     = 0; %4.3e-5/barsa; % will convert to compr/Pa
pvMult              = 0; %1e-5/barsa;
isDissOn            = false;
dis_max             = (53 * kilogram / meter^3) / rhoCref; % from CO2store

% kwm? 0.75, 0.54 in Appendix of Singh et al 2010.


% OPTION - Select which parameters to modify from original data:
mod_rock_perm   = false;   
mod_rock_poro   = false;
mod_rhoCO2      = false;

% Then, set parameter modifier factors:
perm_mod    = 3;
por_mod     = 0.6;
rhoCO2_mod  = 2/3;



% ************************ END OF USER OPTIONS ****************************


%% 1. Load formation
% makeSleipnerModelGrid() looks for file or generates it from grdecl files
% and writes .mat file. Output is the variables G, Gt, rock, rock2D.

% get case info:
switch mycase
    
    case 'useIEAGHG_model'
        modelname   = 'IEAGHGmodel';

    case 'useOriginal_model'
        modelname   = 'ORIGINALmodel';
        
    case 'useInhouse_model'
        modelname   = 'INHOUSEmodel';
        
    otherwise
        error('No such case')
end

switch myresolution
    
    case 'useRefinedGrid'
        refnum = refineLevel;
        
    otherwise
        refnum = 1;
end

% make grid model:
fprintf(['\nYour case is set to ' mycase '.\n'])
fprintf(['You have chosen to refine the model grid ',num2str(refnum),' times.\n'])
fprintf('\nGetting grid...\n\n')
[ G, Gt, rock, rock2D ] = makeSleipnerModelGrid('modelName', modelname, 'refineLevel',refnum);
fprintf('\n\nGrid obtained.\n')

    
%% Modify original parameters (optional) and visualize model grids
if mod_rock_perm
    disp('Original rock permeabilities are being modified ...')
    rock.perm   = rock.perm .* perm_mod;
    rock2D.perm = rock2D.perm .* perm_mod;
end

if mod_rock_poro
    disp('Original rock porosities are being modified ...')
    rock.poro   = rock.poro .* por_mod;
    rock2D.poro = rock2D.poro .* por_mod;
end
    
if plotModelGrid
    [ hfig, hax ] = plot3DandTopGrids( G, Gt );
    
end


% Get boundary faces of formation (or grid region)
bf = boundaryFaces(Gt);


%% 2. Basic routine to perform VE simulation, using simulateScheduleAD().
% _________________________________________________________________________
% a) set up initial state, OR get literature data:


if mod_rhoCO2
    disp('Original CO2 density value is being modified ...')
    rhoCref = rhoCref * rhoCO2_mod; 
end

initState.pressure  = Gt.cells.z * norm(gravity) * water_density;   % hydrostatic pressure, in Pa=N/m^2
initState.s         = repmat([1 0], Gt.cells.num, 1);               % sat of water is 1, sat of CO2 is 0
initState.sGmax     = initState.s(:,2);                             % max sat of CO2 is initially 0
initState.rs        = 0 * initState.sGmax;                          % initially 0

if plotInitialPressure
    figure;
    plotCellData(Gt, initState.pressure, 'EdgeColor','none')
    title('Initial Pressure','fontSize', 18);
    % setColorbarHandle() is able to deal with handles of class 'double'
    % (pre-R2014) and graphic objects (post-R2014)
    [ ~ ] = setColorbarHandle( gcf, 'LabelName', 'Pascals', 'fontSize', 18 );
    axis off tight equal
end


% _________________________________________________________________________
% b) set up schedule (wells, bc, etc.).

% WELLS:

dv = bsxfun(@minus, Gt.cells.centroids(:,1:2), [wellXcoord, wellYcoord]);
[v,i] = min(sum(dv.^2, 2));

wellCellIndex = i; % or Gt.cells.indexMap(i);

[i, j] = ind2sub(Gt.cartDims, wellCellIndex);


% Check coordinate that wellCellIndex corresponds to:
wellCoord_x = Gt.cells.centroids(wellCellIndex,1);
wellCoord_y = Gt.cells.centroids(wellCellIndex,2);
wellCoord_z = 0;

% Compare actual against simulated injection location
if plotActualVsSimInjectLocation
    [ hfig, hax ] = plotRealVsDiscreteInjLoc(Gt,bf,wellXcoord,wellYcoord,wellCoord_x,wellCoord_y);
end

inj_rates_MtPerYr = inj_rates.*(rhoCref/1e9*365*24*60*60); % Mt/year


% Put into schedule fields --> [inj period 1; inj period 2; etc...; migration period]
for i = 1:numel(inj_rates)
    schedule.control(i).W = addWell([], Gt.parent, rock2D, wellCellIndex, ...
        'name', sprintf('W%i', i), 'Type', 'rate', 'Val', inj_rates(i), 'comp_i', [0 1]); % inj_rate should be mass rate / fluid.rhoGS 
end
schedule.control(end+1).W       = schedule.control(1).W;
schedule.control(end).W.name    = 'W_off';
schedule.control(end).W.val     = 0;



% BOUNDARY CONDITIONS: (TODO - put in function and give options for
% different bdry condition types)
% First get the faces of the boundaries. face.neighbors are the indices of
% the cells on either side of the faces, i.e., face.neighbor(100,1) and
% face.neighbor(100,2) give the index of the cells on either side of face
% with index 100. Any 0 cell index means there is no cell, i.e., the face
% is along an external boundary of the domain. Thus bdryFaces may be
% obtained by finding all the face indices that contain a 0 cell index on
% either side. (But will this include 'top' and 'bottom' faces?)
bdryFaces = find( Gt.faces.neighbors(:,1).*Gt.faces.neighbors(:,2) == 0 );

bdryVal  = Gt.faces.z(bdryFaces) * water_density * norm(gravity);
% Then use function bc = addBC(bc, faces, type, value, varargin)
bc = addBC( [], bdryFaces, 'pressure', bdryVal, 'sat', [1 0] );


% Put into schedule fields --> [injection period; migration period]
for i = 1:numel(schedule.control)
    schedule.control(i).bc = bc;
end
             

% TIME STEP:

% For simulation schedule
istepvec = repmat( ones(inj_steps, 1) * dTi , [numel(inj_rates) 1] );
mstepvec = ones(mig_steps, 1) * dTm;


% schedule.step.val and schedule.step.control are same size arrays:
% schedule.step.val is the timestep (size) used for that control step.
schedule.step.val       = [istepvec; mstepvec];
% schedule.step.control is a index (1,2,...) indicating which control
% (i.e., schedule.control) is to be used for the timestep.
schedule.step.control = [];
for i = 1:numel(schedule.control)
    
    if schedule.control(i).W.val ~= 0
        % an injection period
        schedule.step.control = [schedule.step.control; ones(inj_steps, 1) * i];

    elseif schedule.control(i).W.val == 0
        % a migration period
        schedule.step.control = [schedule.step.control; ones(mig_steps, 1) * i];
        
    end

end


% confirm inj_rate, inj_year, and time steps
if plotInjectRateOverTime
    [ hfig, hax, timeSinceInj, massNow ] = plotInjectRateVsTime(schedule,inj_year,rhoCref);
end


% _________________________________________________________________________
% c) set up model (grid, rock and fluid properties).

caprock_temperature = 273.15 + seafloor_temp + (Gt.cells.z - seafloor_depth) / 1e3 * temp_gradient; % Kelvin

% pressure at which water density equals the reference density:
ref_p           = mean(initState.pressure); % use mean pressure as ref for linear compressibilities


fluid = makeVEFluid(Gt, rock2D, 'sharp interface', ...
                              'fixedT'      , caprock_temperature, ...
                              'wat_mu_ref'  , mu(1), ...
                              'co2_mu_ref'  , mu(2), ...
                              'wat_rho_ref' , water_density, ...
                              'co2_rho_ref' , rhoCref, ...
                              'wat_rho_pvt' , [water_compr_val, ref_p], ...
                              'pvMult_p_ref', ref_p, ...
                              'pvMult_fac'  , pvMult, ...
                              'residual'    , [sw, sr] , ...
                              'dissolution' , isDissOn, 'dis_max', dis_max);
model = CO2VEBlackOilTypeModel(Gt, rock2D, fluid);


% Prepare plotting (from runSleipner.m)
% We will make a composite plot that consists of several parts: a 3D plot
% of the plume, a pie chart of trapped versus free volume, a plane view of
% the plume from above, and two cross-sections in the x/y directions
% through the well
% opts = {'slice', wellCellIndex, 'Saxis', [0 1-fluid.res_water], ...
%    'maxH', 5, 'Wadd', 10, 'view', [130 50]};
% plotPanelVE(G, Gt, W, sol, 0.0, ones(1,6), opts{:}); % or zeros(1,6);



% _________________________________________________________________________
% d) call to simulateScheduleAD().

disp('do you wish to proceed to solver?')
pause

[wellSols, states, sim_report] = simulateScheduleAD(initState, model, schedule);


% Save variables in workspace:
% first, close all figures
close all
if strcmpi(mycase(1:3), 'use') && strcmpi(mycase(end-5:end), '_model')
    name = mycase(4:end-6);
end
if strcmpi(myInjRates(1:3), 'use')
    rateName = myInjRates(4:end);
end
fileName = [name 'refNum' num2str(refnum) '_' rateName '_' 'ModPermPoroRho' num2str(mod_rock_perm) num2str(mod_rock_poro) num2str(mod_rhoCO2) '_' datestr(clock,30)];
save(fileName);


end
% end of new injection scenario.






















% _________________________________________________________________________
%% Post-Processing:
% note: some variables or functions might have to be loaded
% specifically, i.e., > load(fileName,'sim_report','wellSols','states','model')
% TODO: check size of function handle model, and consider loading (or
% saving) only parts needed

if performPostProcessing
    plotPanelVE                     = false;
    plotModelGrid                   = false;
    plotInitialPressure             = false;
    plotActualVsSimInjectLocation   = false;
    plotInjectRateOverTime          = false;
    plotBHPvsTime                   = false;
    plotAccumCO2vsTime              = false;
    plotEndOfSimResults             = false;
    plotCO2simVsCO2obsData          = true; ZoomIntoPlume = true; % if false, entire grid is plotted
    plotTrappingInventory           = true;
    plotTrapProfiles                = false;
    plotTrapAndPlumeCompare         = false;
    showTableOfTrapDetails          = false;
    plotSideProfileCO2heights       = true;
    
    
    
% Call to trap analysis, used for a few plotting functions
if ~exist('isCellBasedMethod','var')
    isCellBasedMethod = false;
end
ta = trapAnalysis(Gt, isCellBasedMethod); % true for cell-based method


% ------------------   plotPanelVE (start) ---------------------- %
% See also: migrateInjection, plotPanelVE
if plotPanelVE

    Years2plot = [1999; 2001; 2002; 2004; 2006; 2008];

    [ hfig, hax ] = makeSideProfilePlots( Years2plot, inj_year, schedule, ...
        G, Gt, sim_report, states, rock2D, fluid, rhoCref, wellCellIndex, ta );

end
% ------------------   plotPanelVE (end)  ---------------------- %

    

% -------------------------------------------------------------------------
% Plots cooresponding to grid and inital set-up:

if plotModelGrid
    [ hfig, hax ] = plot3DandTopGrids( G, Gt );
end

if plotInitialPressure
    figure;
    plotCellData(Gt, initState.pressure, 'EdgeColor','none')
    title('Initial Pressure','fontSize', 18);
    [ ~ ] = setColorbarHandle( gcf, 'LabelName', 'Pascals', 'fontSize', 18 );
    axis off tight equal
end

if plotActualVsSimInjectLocation
    [ hfig, hax ] = plotRealVsDiscreteInjLoc(Gt,bf,wellXcoord,wellYcoord,wellCoord_x,wellCoord_y);
end

if plotInjectRateOverTime
    [ hfig, hax ] = plotInjectRateVsTime(schedule,inj_year,rhoCref);
end
    


% -------------------------------------------------------------------------
% Plots cooresponding to VE simulation results:

% BHP VS TIME
if plotBHPvsTime
    time = sim_report.ReservoirTime;
    bhp = zeros(numel(wellSols),1);
    for i = 1:numel(wellSols)
        bhp(i) = wellSols{i}.bhp; % bhp is in Pa=N/m^2
    end
    figure;
    plot(time/365/24/60/60,bhp,'x--')
    xlabel('Reservoir time, years'); ylabel('well bhp, Pascals=10^{-5}bars');
end


% ACCUM CO2 VS TIME (compare this plot against Cavanagh 2013, fig 3)
if plotAccumCO2vsTime
    time = sim_report.ReservoirTime;
    accumCO2sat = zeros(numel(states),1);
    accumCO2mass = zeros(numel(states),1);
    for i = 1:numel(states)
        accumCO2sat(i) = sum( states{i}.s(:,2).*model.G.cells.volumes ); % sat vals are in terms of pore volume
        satCO2          = states{i}.s(:,2);
        densityCO2      = fluid.rhoG(states{i}.pressure); 
        accumCO2mass(i) = sum( model.rock.poro .* model.G.cells.volumes .* model.G.cells.H .* satCO2 .* densityCO2 );
    end
    figure;
    plot(time/365/24/60/60,accumCO2mass/1e9,'o-')
    xlabel('Reservoir time, years'); ylabel('Accumlated CO2 mass, Mt (or 10^9 kg)');
end


% END of SIMULATION PROFILES
% use 'final' or the year
if plotEndOfSimResults
    [ hfig, hax ] = plotProfilesAtGivenTime('final', inj_year, Gt, states, initState, fluid, model, sim_report, caprock_temperature);
end



% INVENTORY (from exploreSimulation.m)
if plotTrappingInventory
    dh = []; % for subscale trapping?
    h2 = figure; plot(1); ax = get(h2, 'currentaxes');
    reports = makeReports(model.G, {initState, states{:}}, model.rock, model.fluid, schedule, ...
                             [model.fluid.res_water, model.fluid.res_gas], ...
                             ta, dh);
    % reports contains soln states; could be used for plotting results.
    directPlotTrappingDistribution(ax, reports, 'legend_location', 'northwest');
    
    %ax = gca;
    %ax.XTickLabel = ax.XTick + inj_year(1)-1;
    % use R2014a and earlier releases syntax to ensure backwards compatibility 
    ax  = get(gca, 'XTick');
    axl = arrayfun(@(a) sprintf('%d', a + inj_year(1)), ax, 'UniformOutput', false);
    set(gca, 'XTickLabel', axl)
    xlabel('Year')
    ylabel('Mass (Mt)')
    set(gca,'FontSize',14)
end


%% Line plots of CO2 migrating plume data
% Note: to run the following function, first downloaded the plume .mat
% files from https://bitbucket.org/mrst/mrst-co2lab/downloads, and place on
% current working directory path
plume = getLayer9CO2plumeOutlines();


% PROFILES AT SELECT TIME
if plotCO2simVsCO2obsData
    
    Years2plot = [1999; 2001; 2002; 2004; 2006; 2008];
    %Years2plot = [2002; 2006; 2008];
    
    [ hfig, hax ] = subplotCO2simVsCO2obsData_basic(Years2plot, inj_year, plume, sim_report, ...
            Gt, states, fluid, model, ...
            wellXcoord, wellYcoord, wellCoord_x, wellCoord_y, ta, ...
            ZoomIntoPlume, ZoomX1, ZoomX2, ZoomY1, ZoomY2, ...
            CO2plumeOutline_SatTol);
        % note the basic function plots in kg, not Mt

end



%% Structural trapping plots

if plotTrapProfiles

    ta_volumes = volumesOfTraps(Gt, ta);
    
    
    % To display analysis method used.
    if isCellBasedMethod
        disp('Trap analysis done using cell-based method.')
    elseif ~isCellBasedMethod
        disp('Trap analysis done using node-based method.')
    end
    
    
    % To display refinement level used, if any.
    if ( exist('myresolution','var') && strcmpi(myresolution,'useRefinedGrid') ) || ( exist('useRefinedGrid','var') && useRefinedGrid )
        fprintf('Refinement level %d:\n', refineLevel);
    elseif ( exist('myresolution','var') && strcmpi(myresolution,'none') ) || ( exist('useRefinedGrid','var') && ~useRefinedGrid )
        disp('No refinement of grid performed.')
    end
    
    
    % Other output.
    fprintf('  Num. global traps: %d\n', numel(ta_volumes));
    fprintf('  Total trap volume: %e m3\n', sum(ta_volumes));
    fprintf('  Avg. global trap size: %e m3\n', mean(ta_volumes));

 
    % PLOT TRAPS COLORED BY CO2 MASS STORAGE CAPACITY
    figure; set(gcf,'Position',[1 1 3000 500])
    hfig = gcf;
    
    %
    subplot(1,5,1); hsub1 = gca; hfsub1 = gcf;
    hold on
    plotFaces(Gt, bf, 'EdgeColor','k', 'LineWidth',3);

    trapcells = ta.traps~=0;
    cellsTrapVol = zeros(Gt.cells.num,1);
    cellsTrapVol(trapcells) = ta_volumes(ta.traps(trapcells));
    plotCellData(Gt, cellsTrapVol/1e3/1e3/1e3, cellsTrapVol~=0, 'EdgeColor','none')

    set(gca,'DataAspect',[1 1 1/100])
    [ ~ ] = setColorbarHandle( gcf, 'LabelName', 'Trap Volume, km^3', 'fontSize', 18 );
    grid; axis tight; set(gca, 'fontSize', 10);


    % GET TRAPPING BREAKDOWN: structural, residual, dissoluion
    % first, compute theoretical capacity (upper bound):
    [ capacityOutput ] = getTrappingCapacities(Gt, rock2D, ta, ...
        rhoCref, water_density, seafloor_temp, seafloor_depth, ...
        temp_gradient, press_deviation, sr, sw, dis_max);

    % Distributed CO2 mass under structural traps: 
    cellsTrapCO2Mass = zeros(Gt.cells.num,1);
    cellsTrapCO2Mass(trapcells) = capacityOutput.strap_mass_co2(trapcells);

    % Cumulative CO2 mass under structural traps:
    trapcaps = accumarray(ta.traps(trapcells), capacityOutput.strap_mass_co2(trapcells));
    trapcap_tot = zeros(Gt.cells.num,1); %ones(size(ta.traps)) * NaN;
    trapcap_tot(trapcells) = trapcaps(ta.traps(trapcells));


    %
    subplot(1,5,2); hsub2 = gca; hfsub2 = gcf;
    hold on
    plotFaces(Gt, bf, 'EdgeColor','k', 'LineWidth',3);
    plotCellData(Gt, cellsTrapCO2Mass/1e9, cellsTrapCO2Mass~=0, 'EdgeColor','none')

    set(gca,'DataAspect',[1 1 1/100])
    [ ~ ] = setColorbarHandle( gcf, 'LabelName', 'Distributed CO2 Mass under Trap, Mt', 'fontSize', 18 );
    grid; axis tight;
    set(gca, 'fontSize', 10); % check for R2014a

    
    %
    subplot(1,5,3); hsub3 = gca; hfsub3 = gcf;
    hold on
    %plotGrid(G, 'EdgeAlpha', 0.1, 'FaceColor', 'none')
    plotFaces(Gt, bf, 'EdgeColor','k', 'LineWidth',3);
    plotCellData(Gt, trapcap_tot/1e9, trapcap_tot~=0, 'EdgeColor','none')

    set(gca,'DataAspect',[1 1 1/100])
    [ ~ ] = setColorbarHandle( gcf, 'LabelName', 'Accumulated CO2 Mass under Trap, Mt', 'fontSize', 18 );
    grid; axis tight; set(gca, 'fontSize', 10);



    % PLOT REACHABLE CAPACITY
    trees = maximizeTrapping(Gt, 'res', ta, 'calculateAll', true, 'removeOverlap', false);
    tvols = [trees.value]; %#ok
    int_tr = find(ta.trap_regions); %#ok ixs of cells spilling into interior trap
    [dummy, reindex] = sort([trees.root], 'ascend'); %#ok

    structural_mass_reached = zeros(Gt.cells.num, 1);
    for i = 1:numel(ta.trap_z) % loop over each trap

        % ix of cells spilling directly into this trap
        cix = find(ta.trap_regions == i);

        % cell indices of all cells of this trap, and its upstream traps
        aix = find(ismember(ta.traps, [trees(reindex(i)).traps]));

        % compute total structural trap capacity (in mass terms) of these
        % cells, and store result
        structural_mass_reached(cix) = sum(capacityOutput.strap_mass_co2(aix)); %#ok

    end

    %
    subplot(1,5,4); hsub4 = gca; hfsub4 = gcf;
    hold on
    plotFaces(Gt, bf, 'EdgeColor','k', 'LineWidth',3);
    plotCellData(Gt, structural_mass_reached/1e3/1e6, 'EdgeColor','none');
    
    set(gca,'DataAspect',[1 1 1/100])
    [ ~ ] = setColorbarHandle( gcf, 'LabelName', 'Reachable structural capacity, Mt', 'fontSize', 18 );
    grid; axis tight; set(gca, 'fontSize', 10);


    % PLOT SPILL PATHS AND TOPOLOGY
    subplot(1,5,5); hsub5 = gca; hfsub5 = gcf;
    hold on
    mapPlot(gcf, Gt, 'traps', ta.traps, 'rivers', ta.cell_lines);

    grid; axis equal tight;

% does not work for R2014a/earlier!
%     % For making plotting adjustments to subplots
%     axesHandles = get(gcf,'children');
%     
%     % Add Injection Location In Each Subplot:
%     for i=1:numel(axesHandles)
%         if strcmpi(axesHandles(i).Type,'axes')
%             
%             subplot(axesHandles(i))
%             % actual location
%             plot(wellXcoord,wellYcoord,'o', ...
%                 'MarkerEdgeColor','k',...
%                 'MarkerFaceColor','r',...
%                 'MarkerSize',10)
%             % simulated location
%             plot(wellCoord_x,wellCoord_y,'x', ...
%                 'LineWidth',3,  ...
%                 'MarkerEdgeColor','k',...
%                 'MarkerFaceColor','k',...
%                 'MarkerSize',10)
%         end
%     end
    
    hfig = gcf;
    hax  = gca;

end


%% Show the structural trap:
% After the simulation has completed, we are interested in seeing how the
% location of the CO2 plume after a long migration time corresponds to the
% trapping estimates produced by trapAnalysis. This is done by finding the
% trap index of the well injection cell and then plotting the trap along
% with the final CO2 plume.

% Plot the areas with any significant CO2 height along with the trap in red
if plotTrapAndPlumeCompare
 
    % Well in 2D model
    WVE = reports(end).W; % take well of last control since first control might be initial conditions (no well)

    % Generate traps and find the trap corresponding to the well cells
    trap = ta.trap_regions([WVE.cells]);
    
    figure; set(gcf,'Position',[1 1 1600 1000])
    plotCellData(Gt, reports(end).sol.h, reports(end).sol.h > 0.01)
    plotGrid(Gt, ta.traps == trap, 'FaceColor', 'red', 'EdgeColor', 'w')
    plotGrid(Gt, 'FaceColor', 'None', 'EdgeAlpha', .1);

    legend({'CO2 Plume', 'Trap'})
    set(gca,'DataAspect',[1 1 1/10])
    axis tight off
    view(20, 25)
    title('End of simulation CO2 compared to algorithmically determined trap')
    
    % Create textarrow
    annotation(gcf,'textarrow',[0.382421875 0.418396875000001],...
    [0.77 0.857197640117995],'String',{'North'});

end

%% Basic capacity estimates and Show table of Structural trapping details
if showTableOfTrapDetails

    if ~exist('mycase','var')
        if useIEAGHG_model
            mycase = 'IEAGHG';
        elseif useOriginal_model
            mycase = 'GHGT';
        end
    end
    if ~exist('myresolution','var')
        if useRefinedGrid
            myresolution = 'useRefinedGrid';
        else
            myresolution = 'none';
        end
    end

       fprintf('------------------------------------------------\n');
       fprintf('Processing case: %s , %s (numRef=%d) ....\n', mycase, myresolution, refineLevel);

       tan     = trapAnalysis(Gt, false);
       tac     = trapAnalysis(Gt, true);

       %tan_volumes = volumesOfTraps(Gt, tan);
       %tac_volumes = volumesOfTraps(Gt, tac);

       i = 1;
       res{i}.name      = mycase;
       if strcmpi(myresolution,'useRefinedGrid')
           res{i}.refLevel  = refineLevel;
       else
           res{i}.refLevel  = 0;
       end
       res{i}.cells     = Gt.cells.num;
       res{i}.zmin      = min(Gt.cells.z);
       res{i}.zmax      = max(Gt.cells.z);
       res{i}.volume    = sum(G.cells.volumes);
       res{i}.surfarea  = sum(Gt.cells.volumes);
       res{i}.ctrapvols = volumesOfTraps(Gt,tac);
       res{i}.ccapacity = sum(res{i}.ctrapvols);
       res{i}.ntrapvols = volumesOfTraps(Gt,tan);
       res{i}.ncapacity = sum(res{i}.ntrapvols);
       fprintf('done\n');

    % create table:
       fprintf('\n\n------------------------------------------------\n');
       fprintf('%-20s& Refined & Cells  & Min  & Max  & Volume   & Capacity  & Percent &  Capacity & Percent\\\\\n', 'Name');

       fprintf('%-20s&   %2d    & %6d & %4.0f & %4.0f & %4.2e & %4.2e  & %5.2f   & %4.2e  & %5.2f \\\\\n',...
          res{i}.name, res{i}.refLevel, res{i}.cells, res{i}.zmin, res{i}.zmax, res{i}.volume, ...
          res{i}.ncapacity, res{i}.ncapacity/res{i}.volume*100, ...
          res{i}.ccapacity, res{i}.ccapacity/res{i}.volume*100);
       fprintf('------------------------------------------------\n');


      fprintf('\n\n---------------Node-based------------------------\n');
      fprintf('%-20s& Refined & Num. global traps & Tot. trap vol. (m3) & Avg. global trap vol. (m3)\\\\\n', 'Name');

      fprintf('%-20s&   %2d    &     %6d        &     %d    &    %d           \\\\\n',...
          res{i}.name, res{i}.refLevel, ...
          numel(res{i}.ntrapvols), ...
          sum(res{i}.ntrapvols), ...
          mean(res{i}.ntrapvols) );
      fprintf('------------------------------------------------\n');

        fprintf('\n\n---------------Cell-based------------------------\n');
      fprintf('%-20s& Refined & Num. global traps & Tot. trap vol. (m3) & Avg. global trap vol. (m3)\\\\\n', 'Name');

      fprintf('%-20s&   %2d    &     %6d        &     %d    &    %d           \\\\\n',...
          res{i}.name, res{i}.refLevel, ...
          numel(res{i}.ctrapvols), ...
          sum(res{i}.ctrapvols), ...
          mean(res{i}.ctrapvols) );
      fprintf('------------------------------------------------\n');

end

%% Side Vertical Profiles through specified cell, i.e., well cell index
% If all states of simulation are passed in, only last state is plotted. If
% the state of a particular year is to be plotted, pass in that state only.

% sim_report.ReservoirTime contains time (in seconds since start of
% simulation) corresponding to the states{}. To find Year (i.e., 2004)
% corresponding to a state:
%I = 5;
%YearOfStateI = inj_year(1) + sim_report.ReservoirTime(I)/(60*60*24*365) - 1;
%state2plot = { states{I} };

% inj_year (the year) correspondes to states
if plotSideProfileCO2heights

    % To plot a specific injection year:
    YearOfStateToPlot = 2008;
    fprintf('\n Plotting year %d \n', YearOfStateToPlot);
    state2plot = { states{ logical(inj_year==YearOfStateToPlot) } };
    [ hfig ] = makeSideProfilePlots_CO2heights( G, Gt, wellCellIndex, state2plot, fluid, 'SleipnerBounded',true);
    
    % To plot a specific state (could be a migration year):
    %I = 5;
    %YearOfStateI = inj_year(1) + sim_report.ReservoirTime(I)/(60*60*24*365) - 1;
    %state2plot = { states{I} };
    %fprintf('\n Plotting year %d \n', YearOfStateI);
    %[ hfig ] = makeSideProfilePlots_CO2heights( G, Gt, wellCellIndex, { states{end} }, fluid, 'SleipnerBounded',true);
    
    % To plot the final state:
    YearOfFinalState = inj_year(1) + sim_report.ReservoirTime(end)/(60*60*24*365) - 1;
    fprintf('\n Plotting final state, year %d \n', YearOfFinalState);
    [ hfig ] = makeSideProfilePlots_CO2heights( G, Gt, wellCellIndex, { states{end} }, fluid, 'SleipnerBounded',true);
    
    % To see all years profiles:
%     for i = 1:numel(states)
%         [ hfig ] = makeSideProfilePlots_CO2heights( G, Gt, wellCellIndex, { states{i} }, fluid, 'SleipnerBounded',true);
%     end
end

end
% end of post-processing





