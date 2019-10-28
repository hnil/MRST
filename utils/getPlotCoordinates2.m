function coords = getPlotCoordinates2(G, varargin)

    opt = struct('n'      , 100  , ...
                 'phaseNo', 1    , ...
                 'plot'   , true , ...
                 'plot1d' , false);
    
    [opt, ~] = merge_options(opt, varargin{:});

    xmax = max(G.nodes.coords, [], 1);
    xmin = min(G.nodes.coords, [], 1);
    
    n0 = sortNodes(G);
    faces = find(all(G.faces.neighbors > 0, 2));
    n1 = G.faces.nodes(mcolon(G.faces.nodePos(faces), G.faces.nodePos(faces+1)-1),1);
    n1 = repmat(reshape(n1,2,[]), 2, 1);
    n1 = reshape(n1([1,2,4,3], :), [], 1);
    n = [n0; n1];
    x = G.nodes.coords(n,:);
    cells0 = rldecode((1:G.cells.num)', diff(G.cells.nodePos), 1);
    
    
    cells1 = repmat(G.faces.neighbors(faces,:)', 2, 1);
    cells1 = reshape(cells1([1,3,2,4], :), [], 1);
    cells = [cells0; cells1];

    f = 1:size(x,1);
    ii = [cells0; rldecode((1:numel(faces))' + max(cells0), 4, 1)];
    jj = [mcolon(ones(G.cells.num,1), diff(G.cells.nodePos)), repmat(1:4, 1, numel(faces))];
    faces = full(sparse(ii, jj, f));
    faces(faces == 0) = nan;
    coords = struct('points', x, 'cells', cells, 'faces', faces);

end
    
function n = sortNodes(G)

    f = G.cells.faces(:,1);
    n = G.faces.nodes(mcolon(G.faces.nodePos(f),G.faces.nodePos(f+1)-1));
    s = G.faces.neighbors(f,1) ~= rldecode((1:G.cells.num)', diff(G.cells.facePos),1);

    n = reshape(n, 2, []);
    n(:,s) = n([2,1], s);
    n = n(:);
    n = n(1:2:end);

end