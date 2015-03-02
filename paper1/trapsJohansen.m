%% Trapping on Johansen grids
% The Johansen formation has been proposed as a potential injection site
% for CO2, in particular when it was planned to capture CO2 from the
% gas-power plant at Mongstad. A simplified representation of the Johansen
% formation was also used as a benchmark case in the Stuttgart code
% comparison study based on a paper by Eigestad et al. Herein, we consider
% the same injection point as suggested by Eigestad et al. and evaluate the
% potential for structural trapping that can be estimated from two
% different models: (i) a sector model developed by the Norwegian Petroleum
% Directorate, which was used to produce the Stuttgart benchmark test, and
% (ii) a model of a somewhat larger region derived from the CO2 Storage
% Atlas for the Norwegian North Sea.

mrstModule add co2lab;
moduleCheck('libgeometry','opm_gridprocessing','coarsegrid','matlab_bgl');

%% Load NPD data: sector model
try
   jdir = fullfile(mrstPath('co2lab'), 'data', 'johansen');
   sector = 'NPD5';
   sector = fullfile(jdir, sector);
   grdecl = readGRDECL([sector '.grdecl']);
catch me
   disp(' -> Download data from: http://www.sintef.no/Projectweb/MatMoRA/')
   disp(['    Putting data in ', jdir]);
   unzip('http://www.sintef.no/project/MatMoRA/Johansen/NPD5.zip', jdir);
   grdecl = readGRDECL([sector '.grdecl']);
end

% Extract the part that represents the Johansen formation
grdecl = cutGrdecl(grdecl,[1 grdecl.cartDims(1); 1 grdecl.cartDims(2);  6 11]);
Gs  = processgrid(grdecl);
Gs  = mcomputeGeometry(Gs);
Gts = topSurfaceGrid(Gs);

% Get the position of the well (data given from 'Sector5_Well.txt');
wi    = find(Gs.cells.indexMap==sub2ind(Gs.cartDims, 48, 48, 1));
wcent = Gs.cells.centroids(wi,:);
d = sqrt(sum(bsxfun(@minus, Gts.cells.centroids, wcent(1:2)).^2, 2));
[~,wi_s] = min(d);

%% Load NPD data: full-field model
try
   jdir = fullfile(mrstPath('co2lab'), 'data', 'johansen');
   sector = 'FULLFIELD_IMAXJMAX';
   sector = fullfile(jdir, sector);
   grdecl = readGRDECL([sector '.GRDECL']);
catch me
   disp(' -> Download data from: http://www.sintef.no/Projectweb/MatMoRA/')
   disp(['    Putting data in ', jdir]);
   unzip('http://www.sintef.no/project/MatMoRA/Johansen/FULLFIELD_Eclipse.zip', jdir);
   grdecl = readGRDECL([sector '.GRDECL']);
end

% Extract the part that represents the Johansen formation
grdecl = cutGrdecl(grdecl,[1 grdecl.cartDims(1); 1 grdecl.cartDims(2);  10 14]);
Gf  = processgrid(grdecl);
Gf  = mcomputeGeometry(Gf);
Gtf = topSurfaceGrid(Gf);

% Get the position of the well
d = sqrt(sum(bsxfun(@minus, Gtf.cells.centroids, wcent(1:2)).^2, 2));
[~,wi_f] = min(d);

%% Load atlas data
grdecl = getAtlasGrid('Johansenfm');
Ga  = processgrid(grdecl{1});
Ga  = mcomputeGeometry(Ga);
Gta = topSurfaceGrid(Ga);

% Get the position of the well
d = sqrt(sum(bsxfun(@minus, Gta.cells.centroids, wcent(1:2)).^2, 2));
[~,wi_a] = min(d);

%% Plot the three data sets
clf
zm = min(Ga.nodes.coords(:,3));
zM = max(Ga.nodes.coords(:,3));

plotCellData(Ga,Ga.cells.centroids(:,3),'FaceAlpha',.95);
plotGrid(Gf,'FaceColor','none','EdgeAlpha',.2,'EdgeColor','r');
plotGrid(Gs,'FaceColor','none','EdgeAlpha',.4,'EdgeColor','k');
axis tight, view(-62,60);
light, lighting phong,
light('Position',[max(Gta.cells.centroids) 4*zM],'Style','infinite');

hold on; plot3(wcent([1 1],1),wcent([1 1],2),[zm zM],'b','LineWidth',2);

legend('Atlas','Full field','Sector','Inj.pt',...
   'Location','SouthOutside','Orientation','horizontal');

%% Interactive trapping: atlas grid
interactiveTrapping(Gta, 'method', 'cell', 'light', true, ...
   'spillregions', true, 'colorpath', false, 'injpt', wi_a);
view(-80,64);

%% Interactive trapping: NPD sector grid
interactiveTrapping(Gts, 'method', 'cell', 'light', true, ...
   'spillregions', true, 'colorpath', false, 'injpt', wi_s);
view(-80,64);


%% Interactive trapping: NPD full-field grid
interactiveTrapping(Gtf, 'method', 'cell', 'light', true, ...
   'spillregions', true, 'colorpath', false, 'injpt', wi_f);
view(-80,64);
