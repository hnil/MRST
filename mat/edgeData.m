function [edges, centroids] = edgeData(G,faces)
    
    edgeNum = mcolon(G.faces.edgePos(faces), G.faces.edgePos(faces+1)-1);
    edges = G.faces.edges(edgeNum,:);
    if size(edges,1) == 1
        edges = edges';
    end
    centroids = G.edges.centroids(edges,:);
    
    
end
