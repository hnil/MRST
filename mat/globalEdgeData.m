function G = globalEdgeData(G)
    edgeVec   = [G.nodes.coords(G.edges.nodes(2:2:end),1) -  ...
                 G.nodes.coords(G.edges.nodes(1:2:end-1),1), ...
                 G.nodes.coords(G.edges.nodes(2:2:end),2) -  ...
                 G.nodes.coords(G.edges.nodes(1:2:end-1),2), ...
                 G.nodes.coords(G.edges.nodes(2:2:end),3) -  ...
                 G.nodes.coords(G.edges.nodes(1:2:end-1),3)];
    lengths   = sqrt(sum(edgeVec.^2,2));
    centroids = [G.nodes.coords(G.edges.nodes(2:2:end),1) +  ...
                 G.nodes.coords(G.edges.nodes(1:2:end-1),1), ...
                 G.nodes.coords(G.edges.nodes(2:2:end),2) +  ...
                 G.nodes.coords(G.edges.nodes(1:2:end-1),2), ...
                 G.nodes.coords(G.edges.nodes(2:2:end),3) +  ...
                 G.nodes.coords(G.edges.nodes(1:2:end-1),3)]./2;
    normals   = [edgeVec(:,3), edgeVec(:,1), -edgeVec(:,2)];
    G.edges.('lengths')   = lengths;
    G.edges.('centroids') = centroids;
    G.edges.('normals')   = normals;
end