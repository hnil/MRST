function CW = upWells(CG, rock, W, varargin)
% Upscale wells
opt = struct(...
    'LinSolve',  @mldivide, ...
    'debug',     false ...
    );
opt = merge_options(opt, varargin{:});

if opt.debug
    % We are in debug mode. We do not spend time on performing well
    % upscaling. Instead, we just add some dummy well indecies.
    CW = makeDummyCGWells(CG, W);
    return;
end

% Compute transmissibility
s = setupSimComp(CG.parent, rock);
T = s.T_all;

% Perform upscaling
warning('off','upscaleTransNew:ZeroBoundary');
[~, ~, CW, ~] = upscaleTransNew(CG, T, ...
   'wells', {W}, 'bc_method', 'wells_simple', ...
   'LinSolve', opt.LinSolve );
warning('on','upscaleTransNew:ZeroBoundary');

end


% Function only used for debugging purposes. Creates a dummy upscaled well
% structure with dummy upscaled well indecies. The method is copied from
% upscaleTransNew, and just slightly altered.
function cgwells = makeDummyCGWells(cg, wells)
cgwells = wells;
for i = 1 : numel(wells),
    fcells  = wells(i).cells;
    cgcells = cg.partition(fcells);
    
    tab        = sortrows([cgcells, fcells, (1 : numel(fcells)) .']);
    [cells, n] = rlencode(tab(:,1));
    fcellspos  = cumsum([1 ; n]);
    
    if cg.griddim > 2,
        pno = rldecode(1 : numel(cells), n, 2) .';
        cc  = cg.parent.cells.centroids(tab(:,2), 3);
        cv  = cg.parent.cells.volumes  (tab(:,2));
        
        hpos = sparse(pno, 1 : numel(pno), cv) ...
            * [ cc, ones([numel(pno), 1]) ];
        
        hpos = hpos(:,1) ./ hpos(:,2);         clear pno cc cv
    else
        hpos = 0;
    end
    
    % Compute WI as some simple average. This is instead of actually
    % upscaling the WI value, and is only used for debugging purposes.
    wi = sum(wells(i).WI.*wells(i).dZ)./sum(wells(i).dZ);
    
    cgwells(i).cells     = cells;
    cgwells(i).WI        = wi.*ones([numel(cells), 1]);
    cgwells(i).dZ        = hpos - wells(i).refDepth;
    cgwells(i).fcellspos = fcellspos;
    cgwells(i).fcells    = tab(:,2);
    cgwells(i).fperf     = tab(:,3);
end

cgwells(i).parent = wells(i);
end

