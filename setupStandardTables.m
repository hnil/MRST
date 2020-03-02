function [tbls, mappings] = setupStandardTables(G)
    
    nc  = G.cells.num;
    nf  = G.faces.num;
    nn  = G.nodes.num;
    dim = G.griddim;

    coltbl.coldim = (1 : dim)';
    coltbl = IndexTable(coltbl);
    rowtbl = coltbl;
    rowtbl = replacefield(rowtbl, {'coldim', 'rowdim'});

    celltbl.cells = (1 : nc)';
    celltbl = IndexTable(celltbl);
    
    nodetbl.nodes = (1 : nn)';
    nodetbl = IndexTable(nodetbl);
    
    cellcoltbl = crossTable(celltbl, coltbl, {}); % ordering is cell - col
    nodecoltbl = crossTable(nodetbl, coltbl, {}); % ordering is cell - col

    cellfacetbl.cells = rldecode((1 : nc)', diff(G.cells.facePos)); 
    cellfacetbl.faces = G.cells.faces(:, 1);
    cellfacetbl = IndexTable(cellfacetbl);
    
    nodefacetbl.faces = rldecode((1 : nf)', diff(G.faces.nodePos)); 
    nodefacetbl.nodes = G.faces.nodes;
    nodefacetbl = IndexTable(nodefacetbl); 
    
    % We setup the face-node table and it is ordered along ascending node numbers so
    % that we will have a block structure for the nodal scalar product.
    nodefacetbl = sortTable(nodefacetbl, {'nodes', 'faces'});
    nodefacecoltbl = crossTable(nodefacetbl, coltbl, {});

    % We setup the cell-face-node table, cellnodefacetbl. Each entry determine a
    % unique facet in a corner
    % We order cellnodeface in cell-node-face order. This is node to optimize
    % for-end loop below.
    cellnodefacetbl = crossTable(cellfacetbl, nodefacetbl, {'faces'});
    cellnodefacetbl = sortTable(cellnodefacetbl, {'cells', 'nodes', 'faces'});

    % We setup the cell-node table, cellnodetbl. Each entry determine a unique
    % corner
    cellnodetbl = projTable(cellnodefacetbl, {'nodes', 'cells'});
    cellnodetbl = sortTable(cellnodetbl, {'cells', 'nodes'});

    map = TensorMap();
    map.fromTbl = celltbl;
    map.toTbl = cellnodetbl;
    map.mergefds = {'cells'};
    cell_from_cellnode = getDispatchInd(map);
    
    map = TensorMap();
    map.fromTbl = nodetbl;
    map.toTbl = cellnodetbl;
    map.mergefds = {'nodes'};
    node_from_cellnode = getDispatchInd(map);
    
    map = TensorMap();
    map.fromTbl = cellfacetbl;
    map.toTbl = cellnodefacetbl;
    map.mergefds = {'cells', 'faces'};
    cellface_from_cellnodeface = getDispatchInd(map);
    
    map = TensorMap();
    map.fromTbl = cellnodetbl;
    map.toTbl = cellnodefacetbl;
    map.mergefds  = {'cells', 'nodes'};
    cellnode_from_cellnodeface = getDispatchInd(map);
    
    map = TensorMap();
    map.fromTbl = nodefacetbl;
    map.toTbl = cellnodefacetbl;
    map.mergefds = {'faces', 'nodes'};
    nodeface_from_cellnodeface = getDispatchInd(map);

    cellnodecoltbl    = crossTable(cellnodetbl, coltbl, {});
    cellnodecolrowtbl = crossTable(cellnodecoltbl, rowtbl, {});

    cellnodefacecoltbl = crossTable(cellnodefacetbl, coltbl, {});
    cellnodefacecolrowtbl = crossTable(cellnodefacecoltbl, rowtbl, {});

    colrowtbl = crossTable(coltbl, rowtbl, {});
    nodecolrowtbl = crossTable(nodetbl, colrowtbl, {});
    
    fds = {{'rowdim', {'rowdim1', 'rowdim2'}}, ...
           {'coldim', {'coldim1', 'coldim2'}}};
    col2row2tbl = crossTable(colrowtbl, colrowtbl, {}, 'crossextend', fds);
    
    cellcol2row2tbl = crossTable(celltbl, col2row2tbl, {});
    
    tbls = struct('coltbl'               , coltbl               , ...
                  'celltbl'              , celltbl              , ...
                  'nodetbl'              , nodetbl              , ...
                  'cellfacetbl'          , cellfacetbl          , ...
                  'cellnodetbl'          , cellnodetbl          , ...
                  'nodefacetbl'          , nodefacetbl          , ...
                  'cellcoltbl'           , cellcoltbl           , ... 
                  'nodecoltbl'           , nodecoltbl           , ... 
                  'nodefacecoltbl'       , nodefacecoltbl       , ... 
                  'cellnodefacetbl'      , cellnodefacetbl      , ... 
                  'cellnodecoltbl'       , cellnodecoltbl       , ...    
                  'cellnodecolrowtbl'    , cellnodecolrowtbl    , ... 
                  'cellnodefacecoltbl'   , cellnodefacecoltbl   , ... 
                  'cellnodefacecolrowtbl', cellnodefacecolrowtbl, ... 
                  'colrowtbl'            , colrowtbl            , ... 
                  'nodecolrowtbl'        , nodecolrowtbl        , ... 
                  'col2row2tbl'          , col2row2tbl          , ... 
                  'cellcol2row2tbl'      , cellcol2row2tbl);

    mappings = struct('cell_from_cellnode'        , cell_from_cellnode        , ...
                      'node_from_cellnode'        , node_from_cellnode        , ...
                      'cellface_from_cellnodeface', cellface_from_cellnodeface, ...
                      'cellnode_from_cellnodeface', cellnode_from_cellnodeface, ...
                      'nodeface_from_cellnodeface', nodeface_from_cellnodeface);
    
end
