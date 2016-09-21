function S = computeVirtualIP(G, rock, k, varargin)

%%  MERGE INPUT PARAMETRES                                               %%

opt = struct('innerProduct', 'ip_simple', ...
             'sigma'       , []              );
opt = merge_options(opt, varargin{:});

%%  CFUNCTION SPACE DIMENSIONS

%   Polynomial space dimension
nk = polyDim(k, G.griddim);

ncn = diff(G.cells.nodePos);
ncf = diff(G.cells.facePos);
if G.griddim == 3; nce = diff(G.cells.edgePos);
else nce = zeros(G.cells.num,1); G.edges.num = 0; end

%   Number of dofs for each face
if G.griddim == 3
    nfn = diff(G.faces.nodePos);
    nfe = diff(G.faces.edgePos);
    NF  = nfn ...
        + nfe*polyDim(k-2, G.griddim-2) ...
        +     polyDim(k-2, G.griddim-1);
end

%   Number of dofs for each cell
NP = ncn                           ...
   + nce*polyDim(k-2, G.griddim-2) ...
   + ncf*polyDim(k-2, G.griddim-1) ...
   +     polyDim(k-2, G.griddim);

%   Dimension of \ker \Pi^\nabla
nker = NP - nk;

%   Total number of dofs
N = G.nodes.num                           ...
  + G.edges.num*polyDim(k-2, G.griddim-2) ...
  + G.faces.num*polyDim(k-2, G.griddim-1) ...
  + G.cells.num*polyDim(k-2, G.griddim  );

%%  CHECK CORRECTNESS OF INPUT

ipNames = {'ip_simple' , 'ip_custom'};

assert(any(strcmp(opt.innerProduct, ipNames)), ...
       'Unknown inner product ''%s''.', opt.innerProduct);

if ~isempty(opt.sigma)
    assert(numel(opt.sigma) == sum(nker));
end


%%  CALCULATE 2D PROJECTOION OPERATORS

K = permTensor(rock, G.griddim);

if G.griddim == 2
    
    %   Calculate projection operators for each cell.
    
    %   Number of nodes and faces for each cell.
    ncn = diff(G.cells.nodePos);
    ncf = diff(G.cells.facePos);
    
    %   Faces for each cell.
    f = G.cells.faces(:,1);
    fn = G.faces.normals(f,:);
    faceSign = (-ones(numel(f),1)).^(G.faces.neighbors(f,1) ...
                  ~= rldecode((1:G.cells.num)', diff(G.cells.facePos), 1)); 
    fn = bsxfun(@times, fn, faceSign);
    if size(f,1) == 1; f = f'; end

    %   Nodes for each face of each cell.
    n = G.faces.nodes(mcolon(G.faces.nodePos(f), ...
                                 G.faces.nodePos(f+1)-1));
    if size(n,1) == 1; n = n'; end
    n   = reshape(n,2,[])';
    n(faceSign == -1,:) = n(faceSign == -1,2:-1:1);
    n   = n(:,1);
    
    %   Function space dimensions.
    
    NP   = ncn + ncf*(k-1) + k*(k-1)/2;
    nker = NP - nk;

    %   Coordinates for degrees of freedom.
    if k == 1
        x = G.nodes.coords(n,:);
    else
        x = [G.nodes.coords(n,:); G.faces.centroids(f,:)];
    end
    
    Kmat = reshape(K', 2, [])';
    
    %   Calculate B and D matrices.
    [B, D, B1, D1] = computeBD2D(G.cells.centroids, G.cells.diameters, ...
                                 G.cells.volumes, ncn, ncf, ...
                                 fn, G.faces.areas(f), G.cells.facePos, ...
                                 x, numel(n), G.cells.nodePos, ...
                                 Kmat, ...
                                 NP, k, G.griddim);
    
    %   Calculate projection operators in monomial (star) and VEM bases.
    M = B*D;
    [ii, jj] = blockDiagIndex(repmat(nk, [G.cells.num ,1]));
    kk = sub2ind(size(M), ii, jj);
%     PiNstar = sparse(ii, jj, invv(full(M(kk)), repmat(nk, [G.cells.num, 1])))*B;
    PiNstar = M\B;
    PiN = D*PiNstar;

    clear B D;

    SS = stabilityTerm(opt.innerProduct, opt.sigma, G, K, PiN, NP, nker);
    
    M(1:nk:end,:) = 0;
    I = speye(size(PiN,1));
    A = PiNstar'*M*PiNstar + (I-PiN)'*SS*(I-PiN);

    %   Make solution struct.
    S = makeSolutionStruct(G, NP, k, A, PiNstar, [], [], []);
else
    
    %%  3D CASE
    
    %%  CALCULATE PROJECTION OPERATORS FOR EACH FACE
    
    nfn = diff(G.faces.nodePos);
    nfe = diff(G.faces.edgePos);
    
    %   Compute local coordinates for each face.

    e  = G.faces.edges;   
    en = G.faces.edgeNormals;
    en = bsxfun(@times, en, G.edges.lengths(e));

    n   = G.edges.nodes(mcolon(G.edges.nodePos(e),G.edges.nodePos(e+1)-1));
    n   = reshape(n,2,[])';
    n(G.faces.edgeSign == -1,:) = n(G.faces.edgeSign == -1,2:-1:1);
    n   = n(:,1);
    nn = numel(n);
    
    x = G.nodes.coords(n,:);

    v1 = (x(G.faces.nodePos(1:end-1)+1,:) - x(G.faces.nodePos(1:end-1),:));
    v1 = bsxfun(@rdivide, v1, sqrt(sum(v1.^2,2)));
    v2 = cross(G.faces.normals,v1,2);
    v2 = bsxfun(@rdivide, v2, sqrt(sum(v2.^2,2)));
    v1 = v1'; v2 = v2';
    T  = sparseBlockDiag([v1(:), v2(:)], repmat(3,[G.faces.num,1]), 1);
    x = sparseBlockDiag(x-rldecode(G.faces.centroids, nfn,1) , nfn, 1);    
    x = squeezeBlockDiag(x*T, nfn, sum(nfn), 2);
                    
    ec = sparseBlockDiag(G.edges.centroids(e,:)-rldecode(G.faces.centroids, nfe, 1), nfe, 1);
    ec = squeezeBlockDiag(ec*T, nfe, sum(nfe), 2);
    
    en = sparseBlockDiag(en, nfe, 1);    
    en = squeezeBlockDiag(en*T, nfe, sum(nfe), 2);
 
    %   Function space dimensions.
    
    
    f = G.cells.faces(:,1);
        
    Kmat = rldecode(K, diff(G.cells.facePos), 1);
    Kmat = Kmat';
    [ii,jj] = blockDiagIndex(repmat(3,[size(Kmat,2), 1]));
    Kmat = sparse(ii, jj, Kmat(:));
    
    T = [v1', v2'];
    T = T(f,:);
    [ii, jj] = blockDiagIndex(repmat(3,[size(T,1),1]),repmat(2,[size(T,1),1]));
    T = T';
    T = sparse(ii, jj, T(:));
    Kmat = squeezeBlockDiag(T'*Kmat*T, repmat(2, [numel(f), 1]), 2*numel(f), 2);
    
%     clear T;
    
    e = G.faces.edges(mcolon(G.faces.edgePos(f), G.faces.edgePos(f+1)-1));
    n = G.faces.nodes(mcolon(G.faces.nodePos(f), G.faces.nodePos(f+1)-1));
   
    
    %   Coordinates for degrees of freedom.
    
    iin = mcolon(G.faces.nodePos(f), G.faces.nodePos(f+1)-1);
    iie = mcolon(G.faces.edgePos(f), G.faces.edgePos(f+1)-1);
    if k == 1
        xx = x(iin,:);
    else
        xx = [x(iin,:); ec(iie,:)];
    end
    
    NP   = nfn + nfe*(k-1) + k*(k-1)/2;
    NP = NP(f);
    
    ePos = diff(G.faces.edgePos);
    ePos = ePos(f);
    ePos = [1;cumsum(ePos)+1];
    nPos = diff(G.faces.nodePos);
    nPos = nPos(f);
    nPos = [1;cumsum(nPos)+1];
    
    
    %   Calculate B and D matrices.
    [BF, DF, ~, ~] = computeBD2D(zeros(numel(f),2), G.faces.diameters(f), ...
                                 G.faces.areas(f), nfn(f), nfe(f), ...
                                 en(iie,:), G.edges.lengths(e), ePos, ...
                                 xx, numel(n), nPos, ...
                                 Kmat, ...
                                 NP, k, G.griddim);

    %   Calculate projection operators in monomial (star) and VEM bases.
    MF = BF*DF;
    [ii, jj] = blockDiagIndex(repmat(nk, [numel(f) ,1]));
    kk = sub2ind(size(MF), ii, jj);
%     PiNFstar = sparse(ii, jj, invv(full(MF(kk)), repmat(nk, [numel(f), 1])))*BF;
    PiNFstar = MF\BF;
    
    clear BF DF;
    
    %%  CALCULATE D MATRICES
    
    [m, grad_m, int_m] = retrieveMonomials(3, k);
    ncn = diff(G.cells.nodePos);
    nce = diff(G.cells.edgePos);
    ncf = diff(G.cells.facePos);
    
    NP = diff(G.cells.nodePos) + diff(G.cells.edgePos)*polyDim(k-2,1) ...
       + diff(G.cells.facePos)*polyDim(k-2, 2) + k*(k^2-1)/6*polyDim(k-2,3);
    nk = polyDim(k, G.griddim);
    
    nker = NP-nk;
    
    f = G.cells.faces(:,1);
    eNum = mcolon(G.faces.edgePos(f), G.faces.edgePos(f+1)-1);
    e = G.faces.edges(eNum);
    en = G.faces.edgeNormals(eNum,:);
    n = G.edges.nodes(mcolon(G.edges.nodePos(e), G.edges.nodePos(e+1)-1));
    n = reshape(n,2,[])';
    n(G.faces.edgeSign(eNum) == -1,:) = n(G.faces.edgeSign(eNum) == -1,2:-1:1);
    n = n(:,1);

    if k == 1
        xMon = bsxfun(@rdivide, G.nodes.coords(G.cells.nodes,:) ...
                               - rldecode(G.cells.centroids, ncn,1), ...
                                 rldecode(G.cells.diameters, ncn, 1));
        mVals = m(xMon);
        D = sparseBlockDiag(mVals, NP, 1);
        D1 = sparseBlockDiag(mVals(:,1), NP, 1);
        
    else
        
        ccf = rldecode(G.cells.centroids, diff(G.cells.facePos), 1);

        cx = trinomialExpansion(v1(1,f)',v2(1,f)', G.faces.centroids(f,1) - ccf(:,1), 1);
        cy = trinomialExpansion(v1(2,f)',v2(2,f)', G.faces.centroids(f,2) - ccf(:,2), 1);
        cz = trinomialExpansion(v1(3,f)',v2(3,f)', G.faces.centroids(f,3) - ccf(:,3), 1);
        
        alpha = [1 0 0]; beta  = [0 1 0];
        
        [alphaBi, betaBi, c6] = polyProducts(cx, cy, alpha, beta);
        [~      , ~     , c7] = polyProducts(cx, cz, alpha, beta);
        [~      , ~     , c9] = polyProducts(cy, cz, alpha, beta);
        
        alphaBi = alphaBi+1;
        c6 = bsxfun(@rdivide, c6, alphaBi);
        c7 = bsxfun(@rdivide, c7, alphaBi);
        c9 = bsxfun(@rdivide, c9, alphaBi);
        
        c5  = trinomialExpansion(v1(1,f)', v2(1,f)', G.faces.centroids(f,1) - ccf(:,1), 2);
        c8  = trinomialExpansion(v1(2,f)', v2(2,f)', G.faces.centroids(f,2) - ccf(:,2), 2);
        c10 = trinomialExpansion(v1(3,f)', v2(3,f)', G.faces.centroids(f,3) - ccf(:,3), 2);
        
        alphaQuad = [2 1 1 0 0 0];
        betaQuad  = [0 1 0 2 1 0];
        alphaQuad = alphaQuad + 1;
        c5 = bsxfun(@rdivide, c5, alphaQuad);
        c8 = bsxfun(@rdivide, c8, alphaQuad);
        c10 = bsxfun(@rdivide, c10, alphaQuad);
        
        fc = rldecode(G.faces.centroids(f,:), nfn(f), 1);
        x = sparseBlockDiag(G.nodes.coords(n,:)-fc, nfn(f), 1);
        x = squeezeBlockDiag(x*T, nfn(f), sum(nfn(f)), 2);
        ec = sparseBlockDiag(G.edges.centroids(e,:) - fc, nfn(f), 1);
        ec = squeezeBlockDiag(ec*T, nfn(f), sum(nfn(f)), 2);
        en = sparseBlockDiag(en, nfn(f), 1);
        en = squeezeBlockDiag(en*T, nfn(f), sum(nfn(f)), 2);
        enx = en(:,1).*G.edges.lengths(e);
        
        pos = [1;cumsum(nfn(f))+1];
        ii = 1:size(x,1); jj = ii;
        jj(1:end-1) = jj(2:end);
        jj(cumsum(pos(2:end)-pos(1:end-1))) = ii([1;cumsum(pos(2:end-1) - pos(1:end-2))+1]);
        
        mVals = bsxfun(@power, repmat([x(:,1); ec(:,1)],1,6), alphaQuad)...
              .*bsxfun(@power, repmat([x(:,2); ec(:,2)],1,6), betaQuad);
        mVals = bsxfun(@times, (mVals(ii,:) + mVals(jj,:))/6 + mVals(size(x,1)+1:end,:)*2/3, enx);
        mVals = sparseBlockDiag(mVals, nfn(f), 1);
        
        I = sparseBlockDiag(ones(1, sum(nfn(f))), nfn(f), 2); 
        cd = rldecode(G.cells.diameters, diff(G.cells.facePos), 1);
        
        c5 = c5';
        m5fInt = I*mVals*c5(:)./cd.^2;
        
        c8 = c8';
        m8fInt = I*mVals*c8(:)./cd.^2;
        
        c10 = c10';
        m10fInt = I*mVals*c10(:)./cd.^2;
        
        mVals = bsxfun(@power, repmat([x(:,1); ec(:,1)],1,3*3), alphaBi)...
              .*bsxfun(@power, repmat([x(:,2); ec(:,2)],1,3*3), betaBi);
        mVals = bsxfun(@times, (mVals(ii,:) + mVals(jj,:))/6 + mVals(size(x,1)+1:end,:)*2/3, enx);
        mVals = sparseBlockDiag(mVals, nfn(f), 1);
        
        I = sparseBlockDiag(ones(1, sum(nfn(f))), nfn(f), 2); 
        cd = rldecode(G.cells.diameters, diff(G.cells.facePos), 1);
        
        c6 = c6';
        m6fInt = I*mVals*c6(:)./cd.^2;
        
        c7 = c7';
        m7fInt = I*mVals*c7(:)./cd.^2;
        
        c9 = c9';
        m9fInt = I*mVals*c9(:)./cd.^2;
        
        fSign = (-ones(numel(f),1)).^(G.faces.neighbors(f,1) ...
                  ~= rldecode((1:G.cells.num)', diff(G.cells.facePos), 1)); 
        fn = bsxfun(@times, G.faces.normals(f,:), fSign./G.faces.areas(f));
        
        cx = [cx, zeros(numel(f), polyDim(2, 3) - polyDim(1,3))];
        cy = [cy, zeros(numel(f), polyDim(2, 3) - polyDim(1,3))];
        cz = [cz, zeros(numel(f), polyDim(2, 3) - polyDim(1,3))];
        c5 = [zeros(numel(f), polyDim(1, 3)-1), bsxfun(@times, c5', alphaQuad)];
        c8 = [zeros(numel(f), polyDim(1, 3)-1), bsxfun(@times, c8', alphaQuad)];
        
        alpha = [1 0 0 2 1 1 0 0 0]; beta = [0 1 0 0 1 0 2 1 0];
        
        [alphaBi, betaBi, c6] = polyProducts(c5, cy, alpha, beta);
        [~      , ~     , c7] = polyProducts(c5, cz, alpha, beta);
        [~      , ~     , c9] = polyProducts(c8, cz, alpha, beta);
        
        c6 = bsxfun(@times, c6, fn(:,1)/2);
        c7 = bsxfun(@times, c7, fn(:,1)/2);
        c9 = bsxfun(@times, c9, fn(:,2)/2);
         
        alphaBi = alphaBi +1;
        
        c6 = bsxfun(@rdivide, c6, alphaBi);
        c7 = bsxfun(@rdivide, c7, alphaBi);
        c9 = bsxfun(@rdivide, c9, alphaBi);
        
        c5 = trinomialExpansion(v1(1,f)', v2(1,f)', G.faces.centroids(f,1) - ccf(:,1), 3);
        c8 = trinomialExpansion(v1(2,f)', v2(2,f)', G.faces.centroids(f,2) - ccf(:,2), 3);
        c10 = trinomialExpansion(v1(3,f)', v2(3,f)', G.faces.centroids(f,3) - ccf(:,3), 3);
        
        c5 = bsxfun(@times, c5, fn(:,1)/3);
        c8 = bsxfun(@times, c8, fn(:,2)/3);
        c10 = bsxfun(@times, c10, fn(:,3)/3);
        
        alphaQuad = [3 2 2 1 1 1 0 0 0 0];
        betaQuad  = [0 1 0 2 0 1 3 2 1 0];
        alphaQuad = alphaQuad + 1;
        
        
        c5 = bsxfun(@rdivide, c5, alphaQuad);
        c8 = bsxfun(@rdivide, c8, alphaQuad);
        c10 = bsxfun(@rdivide, c10, alphaQuad);
        
        pos = [1;cumsum(nfn(f))+1];
        ii = 1:size(x,1); jj = ii;
        jj(1:end-1) = jj(2:end);
        jj(cumsum(pos(2:end)-pos(1:end-1))) = ii([1;cumsum(pos(2:end-1) - pos(1:end-2))+1]);
        
        
        eVec = G.nodes.coords(G.edges.nodes(2:2:end),:)...
             - G.nodes.coords(G.edges.nodes(1:2:end),:);
        xq1 = G.edges.centroids - .5*sqrt(1/5)*eVec;
        xq2 = G.edges.centroids + .5*sqrt(1/5)*eVec;
        
        xq1 = sparseBlockDiag(xq1(e,:)-fc, nfn(f), 1);
        xq1 = squeezeBlockDiag(xq1*T, nfn(f), sum(nfn(f)), 2);
        
        xq2 = sparseBlockDiag(xq2(e,:)-fc, nfn(f), 1);
        xq2 = squeezeBlockDiag(xq2*T, nfn(f), sum(nfn(f)), 2);
        
        
        nn = size(x,1);
        mVals = bsxfun(@power, repmat([x(:,1); xq1(:,1); xq2(:,1)],1,10), alphaQuad)...
              .*bsxfun(@power, repmat([x(:,2); xq1(:,2); xq2(:,2)],1,10), betaQuad);
        mVals = bsxfun(@times, (mVals(ii,:) + mVals(jj,:))/12 + (mVals(nn + 1:2*nn,:) + mVals(2*nn+1:3*nn,:))*5/12, enx);
        mVals = sparseBlockDiag(mVals, nfn(f), 1);
        
        If = sparseBlockDiag(ones(1, sum(nfn(f))), nfn(f), 2); 
        Ic = sparseBlockDiag(ones(1, sum(ncf)), ncf, 2); 
        
        c5 = c5';
        m5cInt = Ic*If*mVals*c5(:)./G.cells.diameters.^2;
        
        c8 = c8';
        m8cInt = Ic*If*mVals*c8(:)./G.cells.diameters.^2;
        
        c10 = c10';
        m10cInt = Ic*If*mVals*c10(:)./G.cells.diameters.^2;
        
        nn = size(x,1);
        mVals = bsxfun(@power, repmat([x(:,1); xq1(:,1); xq2(:,1)],1,9*9), alphaBi)...
              .*bsxfun(@power, repmat([x(:,2); xq1(:,2); xq2(:,2)],1,9*9), betaBi);
        mVals = bsxfun(@times, (mVals(ii,:) + mVals(jj,:))/12 + (mVals(nn + 1:2*nn,:) + mVals(2*nn+1:3*nn,:))*5/12, enx);
        mVals = sparseBlockDiag(mVals, nfn(f), 1);
        
        c6 = c6';
        m6cInt = Ic*If*mVals*c6(:)./G.cells.diameters.^2;
        
        c7 = c7';
        m7cInt = Ic*If*mVals*c7(:)./G.cells.diameters.^2;
        
        c9 = c9';
        m9cInt = Ic*If*mVals*c9(:)./G.cells.diameters.^2;
                
        alpha = [0 1 0 0 2 1 1 0 0 0];
        beta  = [0 0 1 0 0 1 0 2 1 0];
        gamma = [0 0 0 1 0 0 1 0 1 2];
        
        ncn = diff(G.cells.nodePos);
        nce = diff(G.cells.edgePos);
        ncf = diff(G.cells.facePos);
        
        
        xMon = bsxfun(@rdivide, G.nodes.coords(G.cells.nodes,:) ...
                              - rldecode(G.cells.centroids, ncn, 1), ...
                                rldecode(G.cells.diameters, ncn, 1));
                            
        mn =   bsxfun(@power, repmat(xMon(:,1),1, nk), alpha) ...
             .*bsxfun(@power, repmat(xMon(:,2),1, nk), beta ) ...
             .*bsxfun(@power, repmat(xMon(:,3),1, nk), gamma );
         
        ecMon = bsxfun(@rdivide, G.edges.centroids(G.cells.edges,:) ...
                              - rldecode(G.cells.centroids, nce, 1), ...
                                rldecode(G.cells.diameters, nce, 1));
        
        me =   bsxfun(@power, repmat(ecMon(:,1),1, nk), alpha) ...
             .*bsxfun(@power, repmat(ecMon(:,2),1, nk), beta ) ...
             .*bsxfun(@power, repmat(ecMon(:,3),1, nk), gamma );
        
        fcMon = bsxfun(@rdivide, G.faces.centroids(f,:) ...
                              - rldecode(G.cells.centroids, ncf, 1), ...
                                rldecode(G.cells.diameters, ncf, 1));
         
        m2m4fInt = bsxfun(@power, repmat(fcMon(:,1),1,3), alpha(2:4) ) ...
                 .*bsxfun(@power, repmat(fcMon(:,2),1, 3), beta (2:4) ) ...
                 .*bsxfun(@power, repmat(fcMon(:,3),1, 3), gamma(2:4) );
            

        dof = [0; cumsum(NP(1:end-1))] + 1;
             
        iiN = mcolon(dof, dof + ncn - 1);
        iiE = mcolon(dof + ncn, dof + ncn + nce - 1);
        iiF = mcolon(dof + ncn + nce, dof + ncn + nce + ncf - 1);
        iiP = mcolon(dof + ncn + nce + ncf, dof + ncn + nce + ncf);
        
        D([iiN, iiE, iiF, iiP], :) ...
            = [mn; me; ...
               ones(numel(f), 1), m2m4fInt, ...
               bsxfun(@rdivide, [m5fInt, m6fInt, m7fInt, m8fInt, m9fInt, m10fInt], G.faces.areas(f)); ...
               ones(G.cells.num,1), zeros(G.cells.num, 3), ...
               bsxfun(@rdivide, [m5cInt, m6cInt, m7cInt, m8cInt, m9cInt, m10cInt], G.cells.volumes)];
        D = sparseBlockDiag(D, NP, 1);
        
%         DD = [];
%         for P = 1:G.cells.num
%             xP = G.cells.centroids(P,:);
%             hP = G.cells.diameters(P);
%             m = @(x) [ones(size(x,1),1), ...
%                       (x(:,1)-xP(1))/hP, ...
%                       (x(:,2)-xP(2))/hP, ...
%                       (x(:,3)-xP(3))/hP, ...
%                       (x(:,1)-xP(1)).^2/hP^2, ...
%                       (x(:,1)-xP(1)).*(x(:,2)-xP(2))/hP^2, ...
%                       (x(:,1)-xP(1)).*(x(:,3)-xP(3))/hP^2, ...
%                       (x(:,2)-xP(2)).^2/hP^2, ...
%                       (x(:,2)-xP(2)).*(x(:,3)-xP(3))/hP^2, ...
%                       (x(:,3)-xP(3)).^2/hP^2];
%             I = [m(G.nodes.coords(G.cells.nodes(G.cells.nodePos(P):G.cells.nodePos(P+1)-1),:)); ...
%                  m(G.edges.centroids(G.cells.edges(G.cells.edgePos(P):G.cells.edgePos(P+1)-1),:)); ...
%                  bsxfun(@rdivide, polygonInt3D(G, G.cells.faces(G.cells.facePos(P):G.cells.facePos(P+1)-1), m, 2), ...
%                         G.faces.areas(G.cells.faces(G.cells.facePos(P):G.cells.facePos(P+1)-1))); ...
%                  polyhedronInt(G, P, m, 2)./G.cells.volumes(P)];
%             DD = [DD; I(:)];
%         end
%         [ii, jj] = blockDiagIndex(NP, nk*ones(G.cells.num,1));
%         DD = sparse(ii,jj,DD);
%         norm(D-DD, 'fro')
    end
    
    %% CALCULATE B MATRICES
    
    N = G.nodes.num + G.edges.num*polyDim(k-2,1) + G.faces.num*polyDim(k-2,2) + G.cells.num*polyDim(k-2,3);    
    NF = diff(G.faces.nodePos) + diff(G.faces.edgePos)*polyDim(k-2, 1) + polyDim(k-2, 2);
    
    Kmat  = reshape(K', 3, [])';
    
    fn = bsxfun(@rdivide, G.faces.normals(f,:),G.faces.areas(f));
    fSign = (-ones(numel(f),1)).^(G.faces.neighbors(f,1) ...
                  ~= rldecode((1:G.cells.num)', diff(G.cells.facePos), 1)); 
    fn = bsxfun(@times, fn, fSign);
    
    if k == 1
        
    fc = rldecode(G.faces.centroids(f,:), nfn(f), 1);
    x = sparseBlockDiag(G.nodes.coords(n,:)-fc, nfn(f), 1);
    x = squeezeBlockDiag(x*T, nfn(f), sum(nfn(f)), 2);
    ec = sparseBlockDiag(G.edges.centroids(e,:) - fc, nfn(f), 1);
    ec = squeezeBlockDiag(ec*T, nfn(f), sum(nfn(f)), 2);
    en = sparseBlockDiag(en, nfn(f), 1);
    en = squeezeBlockDiag(en*T, nfn(f), sum(nfn(f)), 2);
    enx = en(:,1).*G.edges.lengths(e);
        
%     Kmat = sparseBlockDiag(Kmat, 3*ones(1,G.cells.num), 1);
    fn = sparseBlockDiag(fn, ncf, 1);
    c = fn*Kmat;
    c = rldecode(c, nfe(f), 1);
    
    alpha = [0 1 0]; beta = [0 0 1];
    alpha = alpha+1;
    
    PiNFs = squeezeBlockDiag(PiNFstar, NF(f), polyDim(k, 2), sum(NF(f)));
    
    c2 = bsxfun(@rdivide, repmat(c(:,1), 1, polyDim(k, 2)), alpha)'.*PiNFs;
    c3 = bsxfun(@rdivide, repmat(c(:,2), 1, polyDim(k, 2)), alpha)'.*PiNFs;
    c4 = bsxfun(@rdivide, repmat(c(:,3), 1, polyDim(k, 2)), alpha)'.*PiNFs;
    
    c2 = sparseBlockDiag(c2, NF(f), 2);
    c3 = sparseBlockDiag(c3, NF(f), 2);
    c4 = sparseBlockDiag(c4, NF(f), 2);

    eNum = mcolon(G.faces.edgePos(f), G.faces.edgePos(f+1)-1);
    e = G.faces.edges(eNum);
    en = G.faces.edgeNormals(eNum,:);
    n = G.edges.nodes(mcolon(G.edges.nodePos(e), G.edges.nodePos(e+1)-1));
    n = reshape(n,2,[])';
    n(G.faces.edgeSign(eNum) == -1,:) = n(G.faces.edgeSign(eNum) == -1,2:-1:1);
    n = n(:,1);
    nn= numel(n);

    mVals = bsxfun(@power, repmat([x(:,1); ec(:,1)],1,nk-1), alpha)...
          .*bsxfun(@power, repmat([x(:,2); ec(:,2)],1,nk-1), beta);
      
    pos = [1;cumsum(nfn(f))+1];
    ii = 1:size(x,1); jj = ii;
    jj(1:end-1) = jj(2:end);
    jj(cumsum(pos(2:end)-pos(1:end-1))) = ii([1;cumsum(pos(2:end-1) - pos(1:end-2))+1]);
    
    mVals = bsxfun(@times, (mVals(ii,:) + mVals(jj,:))/6 + mVals(size(x,1)+1:end,:)*2/3, enx);
    
    If = sparseBlockDiag(ones(1, sum(nfe(f))), nfe(f), 2); 
    mVals = If*mVals;
    mVals(:,2:3) = bsxfun(@rdivide, mVals(:,2:3), G.faces.diameters(f));
    
    mVals = sparseBlockDiag(mVals, ones(numel(f),1), 1);
    int2 = mVals*c2;
    int2 = squeezeBlockDiag(int2, NF(f), 1, sum(NF(f)));
    int3 = mVals*c3;
    int3 = squeezeBlockDiag(int3, NF(f), 1, sum(NF(f)));
    int4 = mVals*c4;
    int4 = squeezeBlockDiag(int4, NF(f), 1, sum(NF(f)));
    
    ii = rldecode((1:numel(f))', NF(f), 1);
    jj = n;
    
    int2 = sparse(ii, jj, int2);
    int3 = sparse(ii, jj, int3);
    int4 = sparse(ii, jj, int4);
    
    If = sparseBlockDiag(ones(1,sum(ncf)), ncf, 2);
    int2 = (If*int2)'; int2 = int2(:);
    int3 = (If*int3)'; int3 = int3(:);
    int4 = (If*int4)'; int4 = int4(:);
    
    
    vec = repmat(G.nodes.num,G.cells.num,1);
    vec = [0; cumsum(vec(1:end-1))];
    ii = G.cells.nodes + rldecode(vec, NP,1);
    int2 = int2(ii);
    int3 = int3(ii);
    int4 = int4(ii);
    
    BT = zeros(sum(NP), nk);
    
    cdi = rldecode(G.cells.diameters, NP, 1);
    BT(:,2:end) = bsxfun(@rdivide, [int2, int3, int4], cdi);
    
%     PiNFs = squeezeBlockDiag(PiNFstar, NF(f), 3, sum(NF(f)));
%     
%     ii = rldecode((1:numel(f))', NF(f), 1);
%     jj = n;
%     PiNFs = sparse(ii, jj, PiNFs(1,:));
%     PiNFs = (If*PiNFs)';
%     
%     vec = repmat(G.nodes.num,G.cells.num,1);
%     vec = [0; cumsum(vec(1:end-1))];
%     ii = G.cells.nodes + rldecode(vec, NP,1);
%     PiNFs = PiNFs(ii);
%     
%     cfa = rldecode(If*G.faces.areas(f), NP, 1);
%     
%     BT(:,1) = PiNFs.*cfa;
    BT(:,1) = rldecode(1./NP, NP, 1);
    
    B = sparseBlockDiag(BT', NP, 2);
    
    M = B*D;
    
    [ii, jj] = blockDiagIndex(repmat(nk, [G.cells.num ,1]));
    kk = sub2ind(size(M), ii, jj);
%     PiNstar = sparse(ii, jj, invv(full(M(kk)), repmat(nk, [G.cells.num, 1])))*B;
    
    PiNstar = M\B;

    PiN = D*PiNstar; 
    
    else
    
    %   Calculate K \nabla m^\alpha \cdot n. For m^2 to m^4, these are constant. 
    fn = sparseBlockDiag(fn, ncf, 1);
    c = fn*Kmat;
    c2 = c(:,1); c3 = c(:,2); c4 = c(:,3);
    c5 = c2*2; c8 = c3*2; c10 = c4*2;
    
    %   Express x-x_P, y-y_P and z-z_P in face coordinates.
    cx = trinomialExpansion(v1(1,f)', v2(1,f)', G.faces.centroids(f,1)-ccf(:,1), 1);
    cy = trinomialExpansion(v1(2,f)', v2(2,f)', G.faces.centroids(f,2)-ccf(:,2), 1);
    cz = trinomialExpansion(v1(3,f)', v2(3,f)', G.faces.centroids(f,3)-ccf(:,3), 1);

    zer = zeros(numel(f),3);
    c5  = bsxfun(@times, cx(:,[3,1,2]), c5 )                                     ; c5  = [c5 , zer];
    c6  = bsxfun(@times, cy(:,[3,1,2]), c2 ) + bsxfun(@times, cx(:,[3,1,2]), c3 ); c6  = [c6 , zer];
    c7  = bsxfun(@times, cz(:,[3,1,2]), c2 ) + bsxfun(@times, cx(:,[3,1,2]), c4 ); c7  = [c7 , zer];
    c8  = bsxfun(@times, cy(:,[3,1,2]), c8 )                                     ; c8  = [c8 , zer];
    c9  = bsxfun(@times, cz(:,[3,1,2]), c3 ) + bsxfun(@times, cy(:,[3,1,2]), c4 ); c9  = [c9 , zer];
    c10 = bsxfun(@times, cz(:,[3,1,2]), c10)                                     ; c10 = [c10, zer];
    
    %   Put coefficients in a suitable format.
    PiNFs = squeezeBlockDiag(PiNFstar', NF(f), sum(NF(f)), polyDim(k,2));
    c2  = rldecode(c2 , NF(f), 1);
    c3  = rldecode(c3 , NF(f), 1);
    c4  = rldecode(c4 , NF(f), 1);
    c5  = rldecode(c5 , NF(f), 1);    
    c6  = rldecode(c6 , NF(f), 1);
    c7  = rldecode(c7 , NF(f), 1);
    c8  = rldecode(c8 , NF(f), 1);
    c9  = rldecode(c9 , NF(f), 1);
    c10 = rldecode(c10, NF(f), 1);
    
    %   Multiply coeffiecients of the monomials
    a = [0 1 0 2 1 0];
    b = [0 0 1 0 1 2];
    c2 = bsxfun(@times, PiNFs, c2);
    c3 = bsxfun(@times, PiNFs, c3);
    c4 = bsxfun(@times, PiNFs, c4);
    [alpha510, beta510, c5 ] = polyProducts(c5 , PiNFs, a, b);
    [~       , ~      , c6 ] = polyProducts(c6 , PiNFs, a, b);
    [~       , ~      , c7 ] = polyProducts(c7 , PiNFs, a, b);
    [~       , ~      , c8 ] = polyProducts(c8 , PiNFs, a, b);
    [~       , ~      , c9 ] = polyProducts(c9 , PiNFs, a, b);
    [~       , ~      , c10] = polyProducts(c10, PiNFs, a, b);
    
    %   Add 1 to all x-coordinate exponents, and divide by result.
    alpha24 = [0 1 0 2 1 0];
    beta24  = [0 0 1 0 1 2];
    alpha24 = alpha24+1;
    c2 = bsxfun(@rdivide, c2, alpha24);
    c3 = bsxfun(@rdivide, c3, alpha24);
    c4 = bsxfun(@rdivide, c4, alpha24);
    
    alpha510 = alpha510 + 1;
    c5  = bsxfun(@rdivide, c5 , alpha510);
    c6  = bsxfun(@rdivide, c6 , alpha510);
    c7  = bsxfun(@rdivide, c7 , alpha510);
    c8  = bsxfun(@rdivide, c8 , alpha510);
    c9  = bsxfun(@rdivide, c9 , alpha510);
    c10 = bsxfun(@rdivide, c10, alpha510);
    
    %   Put in block diagonal format.
    c2  = sparseBlockDiag(c2' , NF(f), 2);
    c3  = sparseBlockDiag(c3' , NF(f), 2);
    c4  = sparseBlockDiag(c4' , NF(f), 2);
    c5  = sparseBlockDiag(c5' , NF(f), 2);
    c6  = sparseBlockDiag(c6' , NF(f), 2);
    c7  = sparseBlockDiag(c7' , NF(f), 2);
    c8  = sparseBlockDiag(c8' , NF(f), 2);
    c9  = sparseBlockDiag(c9' , NF(f), 2);
    c10 = sparseBlockDiag(c10', NF(f), 2);

    %   Integrate monomials over each edge of each face using three-point
    %   (m^2-m^4) and four-point (m^5-m^10) Gauss-Lobatto quadratures.
    m2m4 = bsxfun(@power, repmat([x(:,1); ec(:,1)],1,6), alpha24)...
          .*bsxfun(@power, repmat([x(:,2); ec(:,2)],1,6), beta24);
    alpha = [0 1 0 2 1 0]; beta = [0 0 1 0 1 2];
    fd = bsxfun(@power, ...
                repmat(repmat(rldecode(G.faces.diameters(f), nfn(f), 1), 2, 1), 1, 6), ...
                alpha + beta);
    m2m4 = m2m4./fd;
    
%     nn = size(x,1);
%     xx = bsxfun(@rdivide, [x; xq1; xq2], repmat(rldecode(G.faces.diameters(f), nfn(f), 1), 3, 1));
%     
%     m5m10 = bsxfun(@power, repmat(xx(:,1),1,6*6), alpha510)...
%            .*bsxfun(@power, repmat(xx(:,2),1,6*6), beta510);
%     
    m5m10 = bsxfun(@power, repmat([x(:,1); xq1(:,1); xq2(:,1)],1,6*6), alpha510)...
           .*bsxfun(@power, repmat([x(:,2); xq1(:,2); xq2(:,2)],1,6*6), beta510);
    alpha = [0 1 0 2 1 0]; beta = [0 0 1 0 1 2];
    alpha = repmat(alpha, 1,6); beta = repmat(beta,1 ,6);
    fd = bsxfun(@power, repmat(repmat(rldecode(G.faces.diameters(f), nfn(f), 1), 3, 1), 1, 6*6), alpha + beta);
%     fd = bsxfun(@power, repmat(repmat(rldecode(G.faces.diameters(f), nfn(f), 1), 3, 1), 1, 6*6), alpha510-1 + beta510);
    m5m10 = m5m10./fd;
    
%     m5m10 = bsxfun(@power, repmat([x(:,1);ec(:,1)],1,6*6), alpha510)...
%           .*bsxfun(@power, repmat([x(:,2);ec(:,2)],1,6*6), beta510 );
%     fd = bsxfun(@power, repmat(repmat(rldecode(G.faces.diameters(f), nfn(f), 1), 2, 1), 1, 6*6), alpha510-1 + beta510);
%     m5m10 = m5m10./fd;
      
    pos = [1;cumsum(nfn(f))+1];
    ii = 1:size(x,1); jj = ii;
    jj(1:end-1) = jj(2:end);
    jj(cumsum(pos(2:end)-pos(1:end-1))) = ii([1;cumsum(pos(2:end-1) - pos(1:end-2))+1]);
    
    
    If = sparseBlockDiag(ones(1, sum(nfe(f))), nfe(f), 2);
    m2m4 = bsxfun(@times, (m2m4(ii,:) + m2m4(jj,:))/6 + m2m4(size(x,1)+1:end,:)*2/3, enx);
    m2m4 = If*m2m4;
    m2m4 = sparseBlockDiag(m2m4, ones(numel(f),1), 1);
%     m5m10 = bsxfun(@times, (m5m10(ii,:) + m5m10(jj,:))/6 + m5m10(size(x,1)+1:end,:)*2/3, enx);
    m5m10 = bsxfun(@times, (m5m10(ii,:) + m5m10(jj,:))/12 + (m5m10(nn + 1:2*nn,:) + m5m10(2*nn+1:3*nn,:))*5/12, enx);
    m5m10 = If*m5m10;
    m5m10 = sparseBlockDiag(m5m10, ones(numel(f),1), 1);
    
%     fdi = rldecode(G.faces.diameters(f), NF(f), 1)';
%     
%     c6 = bsxfun(@times, c6, fdi);
%     c7 = bsxfun(@times, c7, fdi);
%     c9 = bsxfun(@times, c9, fdi);
    
    %   Map to global dofs and sum for each cell
    int2  = squeezeBlockDiag(m2m4*c2  , NF(f), 1, sum(NF(f)));
    int3  = squeezeBlockDiag(m2m4*c3  , NF(f), 1, sum(NF(f)));
    int4  = squeezeBlockDiag(m2m4*c4  , NF(f), 1, sum(NF(f)));
    int5  = squeezeBlockDiag(m5m10*c5 , NF(f), 1, sum(NF(f)));   
    int6  = squeezeBlockDiag(m5m10*c6 , NF(f), 1, sum(NF(f)));
    int7  = squeezeBlockDiag(m5m10*c7 , NF(f), 1, sum(NF(f)));
    int8  = squeezeBlockDiag(m5m10*c8 , NF(f), 1, sum(NF(f)));
    int9  = squeezeBlockDiag(m5m10*c9 , NF(f), 1, sum(NF(f)));
    int10 = squeezeBlockDiag(m5m10*c10, NF(f), 1, sum(NF(f)));
    
    ii = rldecode((1:numel(f))', NF(f), 1);
    NFf = NF(f);
    dof = [0; cumsum(NFf(1:end-1))] + 1;
    iiN = mcolon(dof, dof + nfn(f) - 1);
    iiE = mcolon(dof + nfn(f), dof + nfn(f) + nfe(f) - 1);
    iiF = mcolon(dof + nfn(f) + nfe(f), dof + nfn(f) + nfe(f));
    
%     e = G.faces.edges(mcolon(G.faces.edgePos(f), G.faces.edgePos(f+1)-1));
%     n = G.edges.nodes(mcolon(G.edges.nodePos(e), G.edges.nodePos(e+1)-1));
%     n = reshape(n,2,[])';
%     n(G.faces.edgeSign(eNum) == -1,:) = n(G.faces.edgeSign(eNum) == -1,2:-1:1);
%     n = n(:,1);
    
    fDof([iiN, iiE, iiF]) = [n; ...
                             e + G.nodes.num; ...
                             f + G.nodes.num + G.edges.num];
    
    int2  = sparse(ii, fDof, int2 , numel(f), N);
    int3  = sparse(ii, fDof, int3 , numel(f), N);
    int4  = sparse(ii, fDof, int4 , numel(f), N);
    int5  = sparse(ii, fDof, int5 , numel(f), N);
    int6  = sparse(ii, fDof, int6 , numel(f), N);
    int7  = sparse(ii, fDof, int7 , numel(f), N);
    int8  = sparse(ii, fDof, int8 , numel(f), N);
    int9  = sparse(ii, fDof, int9 , numel(f), N);
    int10 = sparse(ii, fDof, int10, numel(f), N);
    
    If    = sparseBlockDiag(ones(1,sum(ncf)), ncf, 2);
    int2  = (If*int2)' ; int2  = int2 (:);
    int3  = (If*int3)' ; int3  = int3 (:);
    int4  = (If*int4)' ; int4  = int4 (:);
    int5  = (If*int5)' ; int5  = int5 (:);
    int6  = (If*int6)' ; int6  = int6 (:);
    int7  = (If*int7)' ; int7  = int7 (:);
    int8  = (If*int8)' ; int8  = int8 (:);
    int9  = (If*int9)' ; int9  = int9 (:);
    int10 = (If*int10)'; int10 = int10(:);
    
    %   Pick out the dofs for each cell
    dof = [0; cumsum(NP(1:end-1))]+1;
    iiN = mcolon(dof, dof + ncn -1)';
    iiE = mcolon(dof + ncn, dof + ncn + nce -1)';
    iiF = mcolon(dof + ncn + nce, dof + ncn + nce + ncf - 1)';
    cDof = zeros(sum(NP), 1);
    cDof([iiN; iiE; iiF]) = [G.cells.nodes; ...
                             G.cells.edges + G.nodes.num; ...
                             f             + G.nodes.num + G.edges.num];
    cDof = cDof(cDof~= 0,:);
    vec = repmat(N,G.cells.num,1);
    vec = [0; cumsum(vec(1:end-1))];
    cDof = cDof + rldecode(vec, NP-1,1);
    
    int = [int2, int3, int4, int5, int6, int7, int8, int9, int10];
    
    int = int(cDof,:);
%     int2  = int2 (cDof);
%     int3  = int3 (cDof);
%     int4  = int4 (cDof);
%     int5  = int5 (cDof);
%     int6  = int6 (cDof);
%     int7  = int7 (cDof);
%     int8  = int8 (cDof);
%     int9  = int9 (cDof);
%     int10 = int10(cDof);
    
    %   Build B matrices
    BT = zeros(sum(NP), nk);
    
    vec = [0; cumsum(NP)] + 1;
    ii = mcolon(vec(1:end-1), vec(2:end)-2);
    
    cdi = rldecode(G.cells.diameters, NP-1, 1);
%     BT(ii,2:end) = [bsxfun(@rdivide, [int2, int3, int4], cdi), ...  
%                     bsxfun(@rdivide, [int5, int6, int7, int8, int9, int10], cdi.^2)];
    BT(ii,2:end) = [bsxfun(@rdivide, int(:, 1:3), cdi), ...  
                    bsxfun(@rdivide, int(:, 4:9), cdi.^2)];



    vec = zeros(G.cells.num,nk);
    vec(:, [1,5:nk]) = [ones(G.cells.num,1), ...
                       bsxfun(@times, -2*[K(:,1:3), K(:,5:6), K(:,9)], ...
                       G.cells.volumes./G.cells.diameters.^2)];
    BT(cumsum(NP),:) = BT(cumsum(NP),:) + vec;
    
    B = sparseBlockDiag(BT', NP, 2);
    
    M = B*D;
    
    I = [];
    for P = 1:G.cells.num
        gm5gm5 = @(x) 4*(x(:,1)-G.cells.centroids(P,1)).^2/G.cells.diameters(P)^2;
        
        I = [I; polyhedronInt(G, P, gm5gm5, 2)];
    end

    [ii, jj] = blockDiagIndex(repmat(nk, [G.cells.num ,1]));
    kk = sub2ind(size(M), ii, jj);
    
%     PiNstar = sparse(ii, jj, invv(full(M(kk)), repmat(nk, [G.cells.num, 1])))*B;    
    PiNstar = M\B;
    PiN = D*PiNstar;
    
    end
    
    SS = stabilityTerm(opt.innerProduct, opt.sigma, G, K, PiN, NP, nker);
    M(1:nk:end,:) = 0;
    I = speye(size(PiN,1));
    A = PiNstar'*M*PiNstar + (I-PiN)'*SS*(I-PiN);

    %   Make solution struct.
    
    S = makeSolutionStruct(G, NP, k, A, PiNstar, PiNFstar, v1, v2);
    
end

end
    
%--------------------------------------------------------------------------

function [B, D, B1, D1] = computeBD2D(cc, cd, cv, ncn, ncf, fn, fa, fPos, x, nn, nPos, K, NP, k, dim)

B1 = []; D1 = [];

[m, grad_m, int_m] = retrieveMonomials(2,k);

nk = (k+1)*(k+2)/2;
nkk = k*(k+1)/2;

nc = numel(cv);
nf = numel(fa);

%%  CALCULATE D MATRICES

if k == 1
    
    xMon = bsxfun(@rdivide, ...
                  x ...
                  - rldecode(cc, ncn, 1), ...
                    rldecode(cd, ncn,1));
    D = m(xMon);
    
    if dim == 2 && k == 1
        D1 = D(:, 1:nkk);
        D1 = sparseBlockDiag(D1, NP, 1);
    end
    D = sparseBlockDiag(D, ncn, 1);
    

else
    
    xMon = bsxfun(@rdivide, ...
                  x ...
                   - repmat(rldecode(cc, ncn, 1),2,1), ...
                     repmat(rldecode(cd, ncn,1),2,1));
    ii = 1:nn; jj = ii;
    jj(1:end-1) = jj(2:end);
    jj(cumsum(ncn)) = ii([1;cumsum(ncn(1:end-1))+1]);
    intD = bsxfun(@times, ( int_m(xMon(ii,:)) + int_m(xMon(jj,:)) )/6 ...
                          + int_m(xMon(nn+1:end,:))*2/3, ...
                          fn(:,1)                   );
    I = sparseBlockDiag(ones(1, sum(ncf)), ncf, 2);
    intD = bsxfun(@times, I*intD, cd./cv);
    
    
    nodeDof = mcolon([1;cumsum(NP(1:end-1))+1],[1;cumsum(NP(1:end-1))+1]+ncn-1);
    edgeDof = nodeDof + rldecode(ncn, ncn, 1)';
    D = zeros(sum(NP), nk);
    D([nodeDof, edgeDof],:) = m(xMon);
    D(cumsum(NP),:) = intD;
    
    D = sparseBlockDiag(D, NP, 1);
    
end

%%  CALCULATE B MATRICES

if k == 1
    
%     K = reshape(K, dim, [])';
    K = sparseBlockDiag(K, 2*ones(1,nc), 1);
    
    fn = bsxfun(@rdivide, fn, ...
                                 rldecode(cd, ncf, 1));
    fn = sparseBlockDiag(fn, ncf, 1);

    B = .5*fn*K;

    ii = 1:nf; jj = ii;
    jj(2:end) = jj(1:end-1);
    jj([1;cumsum(fPos(2:end-1)    ...
                -fPos(1:end-2))+1]) ...
     = ii(cumsum(fPos(2:end)-fPos(1:end-1)));

    B = B(ii,:) + B(jj,:);
    B = [.5*(fa(ii) + fa(jj)), ...
                                   squeezeBlockDiag(B,ncf, nf, nk-1)];
    
    if dim == 2 && k == 1
        B1 = B(:,1:nkk);
        B1 = sparseBlockDiag(B1', NP, 2);
    end
    
    B = sparseBlockDiag(B', NP, 2);
    
else
    
    gm = grad_m(xMon);
    ii = repmat((1:5*sum(ncn+ ncf))',2,1);
    jj = repmat(1:2,5*sum(ncn + ncf),1);
    add = repmat([rldecode((0:2:2*(nc-1))', ncn,1);rldecode((0:2:2*(nc-1))', ncf,1)], 5,1);
    jj = bsxfun(@plus,jj,add);
    jj = jj(:);
    
    intB = sparse(ii, jj, gm(:), 5*sum(ncn+ ncf), 2*nc)*K;
    
    %   Dot product by length-weighted face normals.
    
    ii = 1:nn; jj = ii;
    jj(2:end) = jj(1:end-1);
    jj(nPos(1:end-1)) = ii(nPos(2:end)-1);
    
    iin = repmat(1:nn, 1, 5) + rldecode(0:(nn+nf):4*(nn+nf), nn*ones(1,5), 2);
    iif =  iin + nn;
    
    intB = sum(intB([iin, iin, iif],:).*...
               [repmat(fn,5,1); repmat(fn(jj,:),5,1); repmat(fn,5,1)], 2);
    
    %   Evaluate line integrals using three-point Gauss-Lobatto.
           
    intB = [reshape((intB(1:numel(iin)) + intB(numel(iin)+1:2*numel(iin)))/6, nn, 5);
            reshape(intB(2*numel(iin)+1:end)*2/3, nn, 5)];
    intB = bsxfun(@rdivide, intB, repmat(rldecode(cd,diff(nPos),1),2,1));

    %   Assmble matrices.
    
    B = zeros(sum(NP), nk);
    B([nodeDof, edgeDof],2:nk) = intB;
    
    K = reshape(K', 4, [])';
    
    vec = zeros(nc,6);
    vec(:, [1,4:6]) = [ones(nc,1), ...
                       bsxfun(@times, -2*[K(:,1),K(:,2), K(:,4)], ...
                       cv./cd.^2)];
    B(cumsum(NP),:) = B(cumsum(NP), :) + vec;

    B = sparseBlockDiag(B', NP, 2);

end

end

%--------------------------------------------------------------------------

function SS = stabilityTerm(innerProduct, sigma, G, K, PiN, NP, nker)

    if G.griddim == 2; iiK = [1 4]; else iiK = [1 5 9]; end

    switch innerProduct

        case 'ip_simple'
            
           
            SS = spdiags(rldecode(G.cells.diameters.^(G.griddim-2)  ...
                                  .*sum(K(:,iiK),2)/numel(iiK),NP,1), ...
                                  0, sum(NP), sum(NP)              );
        
        case 'ip_custom'
            
            Q = zeros(sum(nker.*NP),1);
            PiNPos = [1; cumsum(NP.^2) + 1];
            QPos   = [1; cumsum(NP.*nker)+1];
            ii = blockDiagIndex(NP);
            PiNvec = full(PiN(ii));

            for P = 1:G.cells.num 
                QP = null(reshape(PiNvec(PiNPos(P):PiNPos(P+1)-1), ...
                          NP(P), NP(P))                               );
                Q(QPos(P):QPos(P+1)-1) = QP(:);
            end

            [ii,jj] = blockDiagIndex(NP, nker);
            Q = sparse(ii, jj, Q, sum(NP), sum(nker));
    
            if isempty(sigma)
                sigma = rldecode(G.cells.diameters.^(G.griddim-2) ...
                                 .*sum(K(:,iiK),2),nker,1);
            end

            SS = Q*spdiags(sigma, 0, sum(nker), sum(nker))*Q';
        
    end
    
end

%--------------------------------------------------------------------------

function S = makeSolutionStruct(G, NP, k, A, PiNstar, PiNFstar, v1, v2)

    if G.griddim == 2
            
        ncn = diff(G.cells.nodePos);
        ncf = diff(G.cells.facePos);
        
        vec = [1, cumsum(NP(1:end-1))' + 1];
        iiN = mcolon(vec, vec + ncn'-1);
        iiF = mcolon(vec + ncn', vec + ncn' + ncf'*polyDim(k-2, 1) -1);
        iiP = mcolon(vec + ncn' + ncf'*polyDim(k-2, 1), ...
                     vec + ncn' + ncf'*polyDim(k-2,1) + polyDim(k-2, 2) -1);
        if k == 1
            dofVec([iiN, iiF, iiP]) = G.cells.nodes';
        else
            dofVec([iiN, iiF, iiP]) ...
                = [G.cells.nodes',...
                   G.cells.faces(:,1)' + G.nodes.num, ...
                   (1:G.cells.num) + G.nodes.num + G.faces.num*polyDim(k-2, 2)];
        end

        S.A = A;
        S.dofVec = dofVec;
        S.PiNstar = PiNstar;
        S.order  = k;

    else
        
        ncn = diff(G.cells.nodePos);
        nce = diff(G.cells.edgePos);
        ncf = diff(G.cells.facePos);

        vec = [1; cumsum(NP(1:end-1)) + 1];
        iiN = mcolon(vec, vec + ncn-1);
        iiE = mcolon(vec + ncn, vec + ncn + nce*polyDim(k-2, 1) - 1);
        iiF = mcolon(vec + ncn + nce*polyDim(k-2, 1), ...
                     vec + ncn + nce*polyDim(k-2, 1) + ncf*polyDim(k-2, 2) - 1);
        iiP = mcolon(vec + ncn + nce*polyDim(k-2, 1) + ncf*polyDim(k-2, 2), ...
                     vec + ncn + nce*polyDim(k-2, 1) + ncf*polyDim(k-2, 2) -1*(k == 1));

        if k == 1
            dofVec([iiN, iiE, iiF, iiP]) = G.cells.nodes';
        else
            dofVec([iiN, iiE, iiF, iiP]) ...
                = [G.cells.nodes', ...
                   G.cells.edges' + G.nodes.num, ...
                   G.cells.faces(:,1)' + G.nodes.num ...
                   + G.edges.num*polyDim(k-2, 1), ...
                   (1:G.cells.num) + G.nodes.num ...
                   + G.edges.num*polyDim(k-2, 1) + G.faces.num*polyDim(k-2, 2)];
        end

        S.A = A;
        S.dofVec = dofVec;
        S.PiNstar = PiNstar;
        S.PiNFstar = PiNFstar;
        S.faceCoords = [v1(:), v2(:)];
        S.order  = k;
        
    end
    
end
    
%--------------------------------------------------------------------------

function coeff = trinomialExpansion(a, b, c, n)
    
    if n == 0
        alpha = 0; beta = 0; gamma = 0;
    elseif n == 1
        alpha = [1,0,0]; beta = [0,1,0]; gamma = [0,0,1];
    elseif n == 2
        alpha = [2,1,1,0,0,0]; beta = [0,1,0,2,1,0]; gamma = [0,0,1,0,1,2];
    else
        alpha = [3 2 2 1 1 1 0 0 0 0];
        beta  = [0 1 0 2 0 1 3 2 1 0];
        gamma = [0 0 1 0 2 1 0 1 2 3];
    end
    
    r = size(a,1);     
    coeff = repmat(factorial(n)./(factorial(alpha).*factorial(beta).*factorial(gamma)), r, 1);
    coeff = coeff.*bsxfun(@power, a,repmat(alpha,r,1))...
         .*bsxfun(@power, b,repmat(beta,r,1))...
         .*bsxfun(@power, c,repmat(gamma,r,1));
    
end

%--------------------------------------------------------------------------

function [alpha, beta, coeff] = polyProducts(coeff1,coeff2,alph, bet)
    [r,c] = size(coeff1);
    cPos  = 1:c:c*c+1;
    coeff = zeros(r, cPos(end)-1);
    alpha = zeros(1, cPos(end)-1);
    beta  = zeros(1, cPos(end)-1);
    for i = 1:c
        coeff(:, cPos(i):cPos(i+1)-1) = coeff1(:, [i:end, 1:i-1]).*coeff2;
        alpha(cPos(i):cPos(i+1)-1) = alph + alph([i:end, 1:i-1]);
        beta(cPos(i):cPos(i+1)-1) = bet + bet([i:end, 1:i-1]);
    end
end

%--------------------------------------------------------------------------

function nk = polyDim(k, dim)
    if k == -1
        nk = 0;
    else
    nk = nchoosek(k+dim,k);
    end
end

