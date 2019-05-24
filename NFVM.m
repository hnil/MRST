classdef NFVM < PermeabilityGradientDiscretization
    properties
        interpFace % Harmonic averaging points
        OSflux % One side fluxes
        %bc % boundary conditions (own struct)
    end
    
    methods
        
        function nfvm = NFVM(model, bc)
            
            
            G = model.G;
            rock = model.rock;
            
            % Setup nfvm members
            %nfvm.bc = bc;
            nfvm.interpFace = nfvm.findHAP(G, rock);
            disp(['fraction of faces with centroids outside convex hull ', num2str(nfvm.interpFace.percentage)]);
            nfvm.interpFace = nfvm.correctHAP(G);
            nfvm.OSflux = nfvm.findOSflux(G, rock,bc,nfvm.interpFace);
        end
        
        function v = getPermeabilityGradient(nfvm, model, state, ~)
            
            maxiter = 100;
            tol = 1e-10;
            
            % Skip ADI
            u0 = state.pressure.val;
            
            T = nfvm.TransNTPFA(model, u0);
            [A, b] = nfvm.AssemAb(model, T, u0); % provide u0 for mu
            iter = 0;
            res = zeros(maxiter+1,1);
            res(1) = norm(A*u0-b,inf);
            while(res(iter+1)>tol*res(1)&&iter<maxiter)
                dispif(mrstVerbose, [num2str(iter), ' ', num2str(res(iter+1)), '\n'])
                u=A\b;
                T=nfvm.TransNTPFA(model, u);
                [A,b]=nfvm.AssemAb(model, T, u);
                iter=iter+1;
                res(iter+1)=norm(A*u-b,inf);
            end
            
            v = nfvm.computeFlux(u,T,model);
            
            % Reduce to interior
            ii = sum(model.G.faces.neighbors ~= 0, 2) == 2;
            v = v(ii);
        end
    end
    
    methods (Access = private)
        
        function T = TransNTPFA(nfvm, model, u)
            
            mu = nfvm.getMuValue(model, u);
            G = model.G;
            T=zeros(G.faces.num,2);
            for i_face=1:G.faces.num
                if(all(G.faces.neighbors(i_face,:)~=0))
                    t1=nfvm.OSflux{i_face,1};
                    t2=nfvm.OSflux{i_face,2};
                    r1=t1(3:end-1,2)'*u(t1(3:end-1,1))+t1(end,2);
                    r2=t2(3:end-1,2)'*u(t2(3:end-1,1))+t2(end,2);
                    eps=1e-12*max(abs([t1(:,end);t2(:,end)]));
                    if(abs(r1)<=eps),r1=0;end
                    if(abs(r2)<=eps),r2=0;end
                    
                    if(abs(r1+r2)>eps)
                        mu1=r2/(r1+r2);mu2=1-mu1;
                    else
                        mu1=0.5; mu2=0.5;
                    end
                    T(i_face,1)=(mu1*t1(1,2)+mu2*t2(2,2))/mu;
                    T(i_face,2)=(mu1*t1(2,2)+mu2*t2(1,2))/mu;
                else
                    %                     ind=find(nfvm.bc.face==i_face,1);
                    %                     if(strcmpi(nfvm.bc.type{ind},'pressure'))
                    %                         t1=nfvm.OSflux{i_face,1};t2=nfvm.OSflux{i_face,2};
                    %                         t11=t1(1,2);t12=t1(2,2);
                    %                         t22=t2(1,2);t21=t2(2,2);
                    %                         r1=t1(3:end-1,2)'*u(t1(3:end-1,1))+t1(end,2);
                    %                         r2=t2(end,2);
                    %                         eps=1e-12*max(abs([t1(:,end);t2(:,end)]));
                    %                         if(abs(r1)<=eps),r1=0;end
                    %                         if(abs(r2)<=eps),r2=0;end
                    %                         if(abs(r1+r2)>eps)
                    %                             mu1=r2/(r1+r2);mu2=1-mu1;
                    %                         else
                    %                             mu1=0.5;mu2=0.5;
                    %                         end
                    %                         T(i_face,1)=mu1*t11+mu2*t21;
                    %                         T(i_face,2)=(mu1*t12+mu2*t22)*nfvm.bc.value{ind}(G.faces.centroids(i_face,:));
                    %                     else
                    %                         T(i_face,2)=-G.faces.areas(i_face)*...
                    %                             nfvm.bc.value{ind}(G.faces.centroids(i_face,:));
                    %                     end
                end
            end
        end
        
        function [A,b]=AssemAb(nfvm, model, T, u)
            mu = nfvm.getMuValue(model, u);
            G = model.G;
            ncf=max(diff(G.cells.facePos));
            nc=G.cells.num;
            b=zeros(nc,1);
            [I,J,V]=deal(zeros(ncf*nc,1));k=1;
            for i_face=1:G.faces.num
                c1=G.faces.neighbors(i_face,1);
                c2=G.faces.neighbors(i_face,2);
                if(all([c1 c2]~=0))
                    I(k)=c1;J(k)=c1;V(k)=T(i_face,1);k=k+1;
                    I(k)=c1;J(k)=c2;V(k)=-T(i_face,2);k=k+1;
                    I(k)=c2;J(k)=c2;V(k)=T(i_face,2);k=k+1;
                    I(k)=c2;J(k)=c1;V(k)=-T(i_face,1);k=k+1;
                else
                    c1=max(c1,c2);
                    I(k)=c1;J(k)=c1;V(k)=T(i_face,1);k=k+1;
                    b(c1)=b(c1)+T(i_face,2);
                end
            end
            %----------------------------------------------------------
            %             W = nfvm.getWells(model);
            %             for i=1:numel(W)
            %                 if(strcmpi(W(i).type,'bhp'))
            %                     pbh=W(i).val;dZ=W(i).dZ;
            %                     for j=1:numel(W(i).cells)
            %                         mycell=W(i).cells(j);
            %                         I(k)=mycell;J(k)=mycell;V(k)=W(i).WI(j)/mu;k=k+1;
            %                         b(mycell)=b(mycell)+W(i).WI(j)/mu*(pbh+model.fluid.rhoWS*9.81*dZ(j));
            %                     end
            %                 else
            %                     % write code here bababababababbababaabababababababababababababba
            %                     error('code under development!')
            %                 end
            %             end
            %-------------------------------------------------------
            I(k:end)=[];J(k:end)=[];V(k:end)=[];
            A=sparse(I,J,V,nc,nc);
        end
        
        function [flux,wellsol]=computeFlux(nfvm,u,T,model)
            
            G = model.G;
            %W = nfvm.getWells(model);
            rho = model.fluid.rhoWS;
            mu = nfvm.getMuValue(model, u);
            
            flux=zeros(G.faces.num,1);
            ind=all(G.faces.neighbors~=0,2);
            c1=G.faces.neighbors(ind,1);c2=G.faces.neighbors(ind,2);
            flux(ind)=T(ind,1).*u(c1)-T(ind,2).*u(c2);
            c1=max(G.faces.neighbors(~ind,:),[],2);
            flux(~ind)=T(~ind,1).*u(c1)-T(~ind,2);
            ind=G.faces.neighbors(:,1)==0;
            flux(ind)=-flux(ind);
            
            %             wellsol=repmat(struct('pressure',[],'flux',[]),[numel(W) 1]);
            %             for i=1:numel(W)
            %                 if(strcmpi(W(i).type,'bhp'))
            %                     pbh=W(i).val;dZ=W(i).dZ;
            %                     wellsol(i).pressure=pbh+rho*9.81*dZ;
            %                     wellsol(i).flux=W(i).WI./mu.*(wellsol(i).pressure-u(W(i).cells));
            %                 else
            %                     error('code under development!');
            %                     % write code here babbabababaababababababababababababababababababab
            %                 end
            %             end
        end
        
        %         function W = getWells(nfvm, model)
        %             % FIXME preallocate
        %             fullW = model.FacilityModel.WellModels;
        %             for i = 1:numel(fullW)
        %                 W(i) = fullW{i}.W;
        %             end
        %         end
        
        function mu = getMuValue(nfvm, model, u)
            % FIXME choose upstream cell for mu or what?
            op = model.operators;
            mu = op.splitFaceCellValue(op, true, model.fluid.muW(u));
            mu = mu(1);
        end
        
        function interpFace=findHAP(nfvm,G,rock)
            %find harmonic averaging points for 2D and 3D grids. Considering both
            %Dirichelt and Neumann boundary conditions
            
            %   interpFace.coords: coordinates of interpolating points
            %   interpFace.weights: interpolating weights
            %   interpFace.percentage: the percentage of cells whose centroid is
            %   outside the convex hull
            
            K=permTensor(rock,G.griddim);
            K=reshape(K',G.griddim,G.griddim,[]);
            interpFace.coords=zeros(G.faces.num,G.griddim);
            interpFace.weights=zeros(G.faces.num,2);
            interpFace.percentage=0;
            % find harmoinc averaging point--------------------------------------------
            for i_face=1:G.faces.num
                c1=G.faces.neighbors(i_face,1);
                c2=G.faces.neighbors(i_face,2);
                xf=G.faces.centroids(i_face,:)';
                if(all([c1 c2]~=0))
                    K1=K(:,:,c1);K2=K(:,:,c2);
                    fn=G.faces.normals(i_face,:)';
                    w1=K1*fn;w2=K2*fn;
                    x1=G.cells.centroids(c1,:)';
                    x2=G.cells.centroids(c2,:)';
                    xA=x1+dot(xf-x1,fn)/dot(w1,fn)*w1;
                    xB=x2+dot(xf-x2,fn)/dot(w2,fn)*w2;
                    w1=norm(w1)/norm(xA-x1);w2=norm(w2)/norm(xB-x2);
                    interpFace.coords(i_face,:)=(w1*xA+w2*xB)'/(w1+w2);
                    interpFace.weights(i_face,1)=w1/(w1+w2);
                    interpFace.weights(i_face,2)=w2/(w1+w2);
                else
                    %                     ind=find(nfvm.bc.face==i_face,1);
                    %                     if(strcmpi(nfvm.bc.type{ind},'pressure'))
                    %                         interpFace.coords(i_face,:)=xf';
                    %                         interpFace.weights(i_face,(c2==0)+1)=nfvm.bc.value{ind}(xf);
                    %                     else
                    %                         c=max(c1,c2);
                    %                         K1=K(:,:,c);
                    %                         fn=G.faces.normals(i_face,:)';
                    %                         w1=K1*fn;
                    %                         x1=G.cells.centroids(c,:)';
                    %                         xA=x1+dot(xf-x1,fn)/dot(w1,fn)*w1;
                    %                         interpFace.coords(i_face,:)=xA';
                    %                         a=norm(w1)/norm(x1-xA);
                    %                         gN=nfvm.bc.value{ind}(xf)*G.faces.areas(i_face);
                    %                         interpFace.weights(i_face,(c1==0)+1)=1;
                    %                         interpFace.weights(i_face,(c2==0)+1)=-gN/a;
                    %                     end
                end
            end
            
            % count the number of cells whose centroid is outside the convex hull-----
            counter=zeros(G.cells.num,1);
            for i=1:G.cells.num
                xc=G.cells.centroids(i,:);
                theFaces=G.cells.faces(G.cells.facePos(i):G.cells.facePos(i+1)-1);
                hap=interpFace.coords(theFaces,:);
                ind=convhull(hap);
                switch G.griddim
                    case 2
                        xv=hap(ind,1);yv=hap(ind,2);
                        counter(i)=inpolygon(xc(1),xc(2),xv,yv);
                    case 3
                        counter(i)=inhull(xc,hap,ind,-1e-5);
                end
            end
            interpFace.percentage=1-sum(counter)/G.cells.num;
        end
        
        function [interpFace]=correctHAP(nfvm,G,myRatio)
            %Correct ill-placed harmonic averaging points. If the number of input
            %arguments is 2, then the correction algorithm is applied only when some
            %cell centroids lie outside their associated convex hull; if the number of
            %input arguments is 3, then the last input argument myRatio is applied to
            %all the harmonic averaging points.
            
            %   G - Grid structure of MRST
            %   interpFace - harmonic averaging point interplation without correction
            %   myRatio - user specified ratio
            
            interpFace = nfvm.interpFace;
            
            HAP=interpFace.coords; % store the locations of the original harmonic averaging points;
            if(nargin==2)
                if(interpFace.percentage>0)
                    if(G.griddim==2)
                        R=0.5*G.faces.areas;
                    else
                        R=sqrt(G.faces.areas./pi);
                    end
                    flag=nfvm.isConvex(G,1:G.cells.num,interpFace);
                    while(flag)
                        mycell=flag;
                        theFaces=G.cells.faces(G.cells.facePos(mycell):G.cells.facePos(mycell+1)-1);
                        neighbors=G.faces.neighbors(theFaces,:);
                        neighbors=unique(neighbors(:));
                        neighbors(neighbors==0)=[];
                        while(flag)
                            d=interpFace.coords(theFaces,:)-G.faces.centroids(theFaces,:);
                            d=sqrt(dot(d,d,2));
                            [maxRatio,ind]=max(d./R(theFaces));
                            y_sigma=HAP(theFaces(ind),:)';
                            interpFace=nfvm.correctHAP_local(G,theFaces(ind),interpFace,y_sigma,0.9*maxRatio);
                            flag=nfvm.isConvex(G,mycell,interpFace);
                        end
                        flag=nfvm.isConvex(G,neighbors(1):G.cells.num,interpFace);
                    end
                end
            elseif(nargin==3)
                if(G.griddim==2)
                    R=0.5*G.faces.areas;
                else
                    R=sqrt(G.faces.areas./pi);
                end
                R=R*myRatio;
                xf=G.faces.centroids;
                hap=interpFace.coords;
                d=hap-xf;
                d=sqrt(dot(d,d,2));
                ind=find(d>R);
                for i=1:numel(ind)
                    interpFace=correctHAP_local(G,ind(i),interpFace,HAP(ind(i),:)',myRatio);
                end
            else
                error('Wrong number of inputs')
            end
        end
        
        function flag=isConvex(nfvm,G,mycells,interpFace)
            switch G.griddim
                case 2
                    flag=0;
                    for i_cell=1:numel(mycells)
                        thecell=mycells(i_cell);
                        xc=G.cells.centroids(thecell,1);
                        yc=G.cells.centroids(thecell,2);
                        theFaces=G.cells.faces(G.cells.facePos(thecell):G.cells.facePos(thecell+1)-1);
                        hap=interpFace.coords(theFaces,:);
                        ind=convhull(hap);
                        xv=hap(ind,1);yv=hap(ind,2);
                        in=inpolygon(xc,yc,xv,yv);
                        if(~in)
                            flag=thecell;break;
                        end
                    end
                case 3
                    flag=0;
                    for i_cell=1:numel(mycells)
                        thecell=mycells(i_cell);
                        xc=G.cells.centroids(thecell,:);
                        theFaces=G.cells.faces(G.cells.facePos(thecell):G.cells.facePos(thecell+1)-1);
                        hap=interpFace.coords(theFaces,:);
                        ind=convhull(hap);
                        in=inhull(xc,hap,ind,-1e-5);
                        %             in=inpolyhedron(ind,hap,xc);
                        if(~in),flag=thecell;break;end
                    end
            end
        end
        
        function interpFace=correctHAP_local(nfvm,G,i_face,interpFace,y_sigma,myRatio)
            % Correct harmonic averaging point for i_face based on given myRatio
            if(myRatio>0)
                if(G.griddim==2)
                    R=0.5*G.faces.areas(i_face)*myRatio;
                elseif(G.griddim==3)
                    R=myRatio*sqrt(G.faces.areas(i_face)/pi);
                end
                xm=G.faces.centroids(i_face,:)';
                interpFace.coords(i_face,:)=(xm+R*(y_sigma-xm)/norm(y_sigma-xm))';
            else
                interpFace.coords(i_face,:)=G.faces.centroids(i_face,:);
            end
        end
        
        function OSflux=findOSflux(nfvm,G,rock,bc,interpFace)
            %Construct one-side fluxes for 2D and 3D grids. Considering general
            %boundary conditions, appending a constant at the last row of
            %transmissibility matrix
            % Dirichlet boundary faces are treated as zero volume cells to derive
            % nonlinear two-point flux approximation for Dirichlet boundary faces
            
            K=permTensor(rock,G.griddim);
            K=reshape(K',G.griddim,G.griddim,[]);
            OSflux=cell(G.faces.num,2);
            
            switch G.griddim
                case 2
                    for i_face=1:G.faces.num
                        if(all(G.faces.neighbors(i_face,:)~=0)) %------------------------------internal face
                            c1=G.faces.neighbors(i_face,1);
                            c2=G.faces.neighbors(i_face,2);
                            K1=K(:,:,c1);K2=K(:,:,c2);
                            w1=K1*G.faces.normals(i_face,:)';
                            w2=-K2*G.faces.normals(i_face,:)';
                            
                            [a,faceA,faceB]=nfvm.findAB(G,interpFace,c1,w1);
                            interpA=[G.faces.neighbors(faceA,:)' interpFace.weights(faceA,:)'];
                            interpB=[G.faces.neighbors(faceB,:)' interpFace.weights(faceB,:)'];
                            interpA(:,2)=-a(1)*interpA(:,2);
                            interpB(:,2)=-a(2)*interpB(:,2);
                            container=[c1;c2;interpA(:,1);interpB(:,1);0];
                            container(:,2)=[sum(a);0;interpA(:,2);interpB(:,2);0];
                            trans=nfvm.uniqueTrans(container);
                            OSflux(i_face,1)={trans};clear trans;
                            
                            [a,faceA,faceB]=nfvm.findAB(G,interpFace,c2,w2);
                            interpA=[G.faces.neighbors(faceA,:)' interpFace.weights(faceA,:)'];
                            interpB=[G.faces.neighbors(faceB,:)' interpFace.weights(faceB,:)'];
                            interpA(:,2)=-a(1)*interpA(:,2);
                            interpB(:,2)=-a(2)*interpB(:,2);
                            container=[c2;c1;interpA(:,1);interpB(:,1);0];
                            container(:,2)=[sum(a);0;interpA(:,2);interpB(:,2);0];
                            trans=nfvm.uniqueTrans(container);
                            OSflux(i_face,2)={trans};clear trans;
                        else  %--------------------------------------------boudary face
                            %                             ind=find(bc.face==i_face,1);
                            %                             if(strcmpi(bc.type{ind},'pressure'))
                            %                                 c1=max(G.faces.neighbors(i_face,:));
                            %                                 cf=G.cells.num+i_face;
                            %                                 K1=K(:,:,c1);
                            %                                 fn=G.faces.normals(i_face,:)';
                            %                                 if(c1~=G.faces.neighbors(i_face,1)),fn=-fn;end
                            %                                 w1=K1*fn;
                            %                                 [a,faceA,faceB]=nfvm.findAB(G,interpFace,c1,w1);
                            %                                 if(i_face==faceA)
                            %                                     interpB=[G.faces.neighbors(faceB,:)' interpFace.weights(faceB,:)'];
                            %                                     interpB(:,2)=-interpB(:,2)*a(2);
                            %                                     container=[c1;cf;interpB(:,1);0];
                            %                                     container(:,2)=[sum(a);-a(1);interpB(:,2);0];
                            %                                 elseif(i_face==faceB)
                            %                                     interpA=[G.faces.neighbors(faceA,:)' interpFace.weights(faceA,:)'];
                            %                                     interpA(:,2)=-interpA(:,2)*a(1);
                            %                                     container=[c1;cf;interpA(:,1);0];
                            %                                     container(:,2)=[sum(a);-a(2);interpA(:,2);0];
                            %                                 else
                            %                                     interpA=[G.faces.neighbors(faceA,:)' interpFace.weights(faceA,:)'];
                            %                                     interpB=[G.faces.neighbors(faceB,:)' interpFace.weights(faceB,:)'];
                            %                                     interpA(:,2)=-a(1)*interpA(:,2);
                            %                                     interpB(:,2)=-a(2)*interpB(:,2);
                            %                                     container=[c1;cf;interpA(:,1);interpB(:,1);0];
                            %                                     container(:,2)=[sum(a);0;interpA(:,2);interpB(:,2);0];
                            %                                 end
                            %                                 trans=nfvm.uniqueTrans(container);
                            %                                 OSflux(i_face,1)={trans};clear trans
                            %
                            %                                 [a,xD]=findDnode(G,c1,i_face,-w1);
                            %                                 uD=bc.value{ind}(xD);
                            %                                 temp=[cf sum(a);c1 a(1);0 a(2)*uD];
                            %                                 OSflux(i_face,2)={temp};clear temp;
                            %                             end
                        end
                    end
                case 3
                    for i_face=1:G.faces.num
                        if(all(G.faces.neighbors(i_face,:)~=0)) %--------------internal face
                            c1=G.faces.neighbors(i_face,1);
                            c2=G.faces.neighbors(i_face,2);
                            K1=K(:,:,c1);K2=K(:,:,c2);
                            w1=K1*G.faces.normals(i_face,:)';
                            w2=-K2*G.faces.normals(i_face,:)';
                            
                            [a,faceA,faceB,faceC]=nfvm.findABC(G,interpFace,c1,w1);
                            interpA=[G.faces.neighbors(faceA,:)' -a(1).*interpFace.weights(faceA,:)'];
                            interpB=[G.faces.neighbors(faceB,:)' -a(2).*interpFace.weights(faceB,:)'];
                            interpC=[G.faces.neighbors(faceC,:)' -a(3).*interpFace.weights(faceC,:)'];
                            container=[c1;c2;interpA(:,1);interpB(:,1);interpC(:,1);0];
                            container(:,2)=[sum(a);0;interpA(:,2);interpB(:,2);interpC(:,2);0];
                            trans=nfvm.uniqueTrans(container);
                            OSflux(i_face,1)={trans};clear trans;
                            
                            [a,faceA,faceB,faceC]=nfvm.findABC(G,interpFace,c2,w2);
                            interpA=[G.faces.neighbors(faceA,:)' -a(1).*interpFace.weights(faceA,:)'];
                            interpB=[G.faces.neighbors(faceB,:)' -a(2).*interpFace.weights(faceB,:)'];
                            interpC=[G.faces.neighbors(faceC,:)' -a(3).*interpFace.weights(faceC,:)'];
                            container=[c2;c1;interpA(:,1);interpB(:,1);interpC(:,1);0];
                            container(:,2)=[sum(a);0;interpA(:,2);interpB(:,2);interpC(:,2);0];
                            trans=nfvm.uniqueTrans(container);
                            OSflux(i_face,2)={trans};clear trans;
                        else  %----------------------------------------------------boudary face
                            %                             ind=find(bc.face==i_face,1);
                            %                             if(strcmpi(bc.type{ind},'pressure'))
                            %                                 c1=max(G.faces.neighbors(i_face,:));
                            %                                 cf=G.cells.num+i_face;
                            %                                 K1=K(:,:,c1);fn=G.faces.normals(i_face,:)';
                            %                                 if(c1~=G.faces.neighbors(i_face,1)),fn=-fn;end
                            %                                 w1=K1*fn;
                            %
                            %                                 [a,faceA,faceB,faceC]=nfvm.findABC(G,interpFace,c1,w1);
                            %                                 if(faceA==i_face)
                            %                                     interpB=G.faces.neighbors(faceB,:)';weightB=-a(2).*interpFace.weights(faceB,:)';
                            %                                     interpC=G.faces.neighbors(faceC,:)';weightC=-a(3).*interpFace.weights(faceC,:)';
                            %                                     container=[c1;cf;interpB;interpC;0];
                            %                                     container(:,2)=[sum(a);-a(1);weightB;weightC;0];
                            %                                 elseif(faceB==i_face)
                            %                                     interpA=G.faces.neighbors(faceA,:)';weightA=-a(1).*interpFace.weights(faceA,:)';
                            %                                     interpC=G.faces.neighbors(faceC,:)';weightC=-a(3).*interpFace.weights(faceC,:)';
                            %                                     container=[c1;cf;interpA;interpC;0];
                            %                                     container(:,2)=[sum(a);-a(2);weightA;weightC;0];
                            %                                 elseif(faceC==i_face)
                            %                                     interpA=G.faces.neighbors(faceA,:)';weightA=-a(1).*interpFace.weights(faceA,:)';
                            %                                     interpB=G.faces.neighbors(faceB,:)';weightB=-a(2).*interpFace.weights(faceB,:)';
                            %                                     container=[c1;cf;interpA;interpB;0];
                            %                                     container(:,2)=[sum(a);-a(3);weightA;weightB;0];
                            %                                 else
                            %                                     interpA=G.faces.neighbors(faceA,:)';weightA=-a(1).*interpFace.weights(faceA,:)';
                            %                                     interpB=G.faces.neighbors(faceB,:)';weightB=-a(2).*interpFace.weights(faceB,:)';
                            %                                     interpC=G.faces.neighbors(faceC,:)';weightC=-a(3).*interpFace.weights(faceC,:)';
                            %                                     container=[c1;cf;interpA;interpB;interpC;0];
                            %                                     container(:,2)=[sum(a);0;weightA;weightB;weightC;0];
                            %                                 end
                            %                                 trans=nfvm.uniqueTrans(container);
                            %                                 OSflux(i_face,1)={trans};clear trans;
                            %
                            %                                 [a,xA,xB]=findDnodes(G,c1,i_face,-w1);
                            %                                 uA=bc.value{ind}(xA);
                            %                                 uB=bc.value{ind}(xB);
                            %                                 temp=[cf sum(a);c1 a(1);0 a(2)*uA+a(3)*uB];
                            %                                 OSflux(i_face,2)={temp};clear temp;
                            %                             end
                        end
                    end
            end
        end
        
        function [a,faceA,faceB]=findAB(nfvm,G,interpFace,c,Kn)
            x1=G.cells.centroids(c,:)';
            theFaces=G.cells.faces(G.cells.facePos(c):G.cells.facePos(c+1)-1,1);
            myBases=interpFace.coords(theFaces,:);
            myBases=bsxfun(@minus,myBases,x1');
            myNorm=sqrt(dot(myBases,myBases,2));
            myBases=bsxfun(@rdivide,myBases,myNorm);
            Kn_norm=norm(Kn);
            Kn_unit=Kn/Kn_norm;
            myangles=bsxfun(@times,myBases,Kn_unit');
            myangles=sum(myangles,2);
            myangles=acos(myangles);
            [~,I]=sort(myangles);
            theFaces=theFaces(I);
            myBases=myBases(I,:);
            myNorm=myNorm(I);
            nf=numel(theFaces);
            flag=0;
            
            myIndex=zeros(nf*(nf-1)/2,2);
            myCoeff=myIndex;counter=1;
            for i=1:nf-1
                tA=myBases(i,:)';
                tA_norm=myNorm(i);
                for j=i+1:nf
                    tB=myBases(j,:)';
                    tB_norm=myNorm(j);
                    if(abs(det([tA tB]))>1e-9)
                        temp_a=[tA tB]\(Kn_unit);
                        temp_a(abs(temp_a)<1e-9)=0;
                        if(all(temp_a>=0))
                            if(all(temp_a<=1))
                                faceA=theFaces(i);
                                faceB=theFaces(j);
                                a=temp_a;
                                a(1)=a(1)*Kn_norm/tA_norm;
                                a(2)=a(2)*Kn_norm/tB_norm;
                                flag=1;break;
                            else
                                myIndex(counter,:)=[i,j];
                                myCoeff(counter,:)=temp_a;
                                counter=counter+1;
                            end
                        end
                    end
                end
                if(flag),break;end
            end
            if(~flag&&counter>1)
                myIndex(counter:end,:)=[];myCoeff(counter:end,:)=[];
                maxCoeff=max(myCoeff,[],2);
                [~,ind]=min(maxCoeff);
                i=myIndex(ind,1);j=myIndex(ind,2);
                a=myCoeff(ind,:);
                faceA=theFaces(i);faceB=theFaces(j);
                tA_norm=myNorm(i);
                tB_norm=myNorm(j);
                a(1)=a(1)*Kn_norm/tA_norm;
                a(2)=a(2)*Kn_norm/tB_norm;
            end
            assert(logical(exist('faceA','var')),...
                ['decomposition failed for cell ',num2str(c)]);
        end
        
        function [a,faceA,faceB,faceC]=findABC(nfvm,G,interpFace,c,Kn)
            x1=G.cells.centroids(c,:)';
            theFaces=G.cells.faces(G.cells.facePos(c):G.cells.facePos(c+1)-1,1);
            myBases=interpFace.coords(theFaces,:);
            myBases=bsxfun(@minus,myBases,x1');
            myNorm=sqrt(dot(myBases,myBases,2));
            myBases=bsxfun(@rdivide,myBases,myNorm);
            Kn_norm=norm(Kn);
            Kn_unit=Kn/Kn_norm;
            myangles=bsxfun(@times,myBases,Kn_unit');
            myangles=sum(myangles,2);
            myangles=acos(myangles);
            [~,I]=sort(myangles);
            theFaces=theFaces(I);
            myBases=myBases(I,:);
            myNorm=myNorm(I);
            nf=numel(theFaces);
            flag=0;
            
            myIndex=zeros(nf*(nf-1)*(nf-2)/6,3);
            myCoeff=myIndex;counter=1;
            for i=1:nf-2
                tA=myBases(i,:)';
                tA_norm=myNorm(i);
                for j=i+1:nf-1
                    tB=myBases(j,:)';
                    tB_norm=myNorm(j);
                    for k=j+1:nf
                        tC=myBases(k,:)';
                        tC_norm=myNorm(k);
                        if(abs(det([tA tB tC]))>1e-9)
                            temp_a=[tA tB tC]\(Kn_unit);
                            temp_a(abs(temp_a)<1e-9)=0;
                            if(all(temp_a>=0))
                                if(all(temp_a<=1))
                                    faceA=theFaces(i);
                                    faceB=theFaces(j);
                                    faceC=theFaces(k);
                                    a=temp_a;
                                    a(1)=a(1)*Kn_norm/tA_norm;
                                    a(2)=a(2)*Kn_norm/tB_norm;
                                    a(3)=a(3)*Kn_norm/tC_norm;
                                    flag=1;break;
                                else
                                    myIndex(counter,:)=[i,j,k];
                                    myCoeff(counter,:)=temp_a;
                                    counter=counter+1;
                                end
                            end
                        end
                    end
                    if(flag),break;end
                end
                if(flag),break;end
            end
            if(~flag&&counter>1)
                myIndex(counter:end,:)=[];myCoeff(counter:end,:)=[];
                maxCoeff=max(myCoeff,[],2);
                [~,ind]=min(maxCoeff);
                i=myIndex(ind,1);j=myIndex(ind,2);k=myIndex(ind,3);
                a=myCoeff(ind,:);
                faceA=theFaces(i);faceB=theFaces(j);faceC=theFaces(k);
                tA_norm=myNorm(i);
                tB_norm=myNorm(j);
                tC_norm=myNorm(k);
                a(1)=a(1)*Kn_norm/tA_norm;
                a(2)=a(2)*Kn_norm/tB_norm;
                a(3)=a(3)*Kn_norm/tC_norm;
            end
            assert(logical(exist('faceA','var')),...
                ['decomposition failed for cell ',num2str(c)]);
        end
        
        function [a,xD]=findDnode(nfvm,G,mycell,myface,Kn)
            n1=G.faces.nodes(G.faces.nodePos(myface));
            n2=G.faces.nodes(G.faces.nodePos(myface)+1);
            xn1=G.nodes.coords(n1,:)';
            xn2=G.nodes.coords(n2,:)';
            xf=G.faces.centroids(myface,:)';
            xc=G.cells.centroids(mycell,:)';
            Kn_norm=norm(Kn);
            Kn=Kn/Kn_norm;
            t_norm=norm(xc-xf);
            t=(xc-xf)/t_norm;
            t1_norm=norm(xn1-xf);
            t1=(xn1-xf)/t1_norm;
            t2_norm=norm(xn2-xf);
            t2=(xn2-xf)/t2_norm;
            temp_a=[t t1]\Kn;
            temp_a(abs(temp_a)<1e-9)=0;
            if(all(temp_a>=0))
                a=temp_a;
                a(1)=a(1)*Kn_norm/t_norm;
                a(2)=a(2)*Kn_norm/t1_norm;
                xD=xn1;
            else
                a=[t t2]\Kn;
                a(abs(a)<1e-9)=0;
                a(1)=a(1)*Kn_norm/t_norm;
                a(2)=a(2)*Kn_norm/t2_norm;
                xD=xn2;
            end
        end
        
        function [a,xA,xB]=findDnodes(nfvm,G,mycell,myface,Kn)
            mynodes=G.faces.nodes(G.faces.nodePos(myface):G.faces.nodePos(myface+1)-1);
            mynodes=[mynodes;mynodes(1)];
            xnode=G.nodes.coords(mynodes,:);
            xc=G.cells.centroids(mycell,:)';
            xf=G.faces.centroids(myface,:)';
            tc_norm=norm(xc-xf);tc=(xc-xf)/tc_norm;
            Kn_norm=norm(Kn);Kn=Kn/Kn_norm;
            for i=1:numel(mynodes)-1
                xA=xnode(i,:)';
                xB=xnode(i+1,:)';
                tA_norm=norm(xA-xf);tA=(xA-xf)/tA_norm;
                tB_norm=norm(xB-xf);tB=(xB-xf)/tB_norm;
                a=[tc tA tB]\Kn;
                a(abs(a)<1e-9)=0;
                if(all(a>=0))
                    a(1)=a(1)*Kn_norm/tc_norm;
                    a(2)=a(2)*Kn_norm/tA_norm;
                    a(3)=a(3)*Kn_norm/tB_norm;
                    break;
                end
            end
        end
        
        function [trans]=uniqueTrans(nfvm,container)
            [trans,~,subs]=unique(container(:,1),'rows','stable');
            trans(:,2)=accumarray(subs,container(:,2));
            trans(3:end,:)=sortrows(trans(3:end,:),-1);
            trans(2:end,2)=-trans(2:end,2);
        end
        
        
        % function [a,faceA,faceB]=findAB(G,interpFace,c,Kn)
        % x1=G.cells.centroids(c,:)';
        % theFaces=G.cells.faces(G.cells.facePos(c):G.cells.facePos(c+1)-1,1);
        % myBases=interpFace.coords(theFaces,:);
        % myBases=bsxfun(@minus,myBases,x1');
        % myNorm=sqrt(dot(myBases,myBases,2));
        % myBases=bsxfun(@rdivide,myBases,myNorm);
        % Kn_norm=norm(Kn);
        % Kn_unit=Kn/Kn_norm;
        % myangles=bsxfun(@times,myBases,Kn_unit');
        % myangles=sum(myangles,2);
        % myangles=acos(myangles);
        % [~,I]=sort(myangles);
        % theFaces=theFaces(I);
        % myBases=myBases(I,:);
        % myNorm=myNorm(I);
        % nf=numel(theFaces);
        % flag=0;
        %
        % myIndex=zeros(nf*(nf-1)/2,2);
        % myCoeff=myIndex;counter=1;
        % for i=1:nf-1
        %     tA=myBases(i,:)';
        %     tA_norm=myNorm(i);
        %     for j=i+1:nf
        %         tB=myBases(j,:)';
        %         tB_norm=myNorm(j);
        %         if(abs(det([tA tB]))>1e-9)
        %             temp_a=[tA tB]\(Kn_unit);
        %             temp_a(abs(temp_a)<1e-9)=0;
        %             if(all(temp_a>=0))
        %                 if(all(temp_a<=1))
        %                     faceA=theFaces(i);
        %                     faceB=theFaces(j);
        %                     a=temp_a;
        %                     a(1)=a(1)*Kn_norm/tA_norm;
        %                     a(2)=a(2)*Kn_norm/tB_norm;
        %                     flag=1;break;
        %                 else
        %                     myIndex(counter,:)=[i,j];
        %                     myCoeff(counter,:)=temp_a;
        %                     counter=counter+1;
        %                 end
        %             end
        %         end
        %     end
        %     if(flag),break;end
        % end
        % if(~flag&&counter>1)
        %     myIndex(counter:end,:)=[];myCoeff(counter:end,:)=[];
        %     maxCoeff=max(myCoeff,[],2);
        %     [~,ind]=min(maxCoeff);
        %     i=myIndex(ind,1);j=myIndex(ind,2);
        %     a=myCoeff(ind,:);
        %     faceA=theFaces(i);faceB=theFaces(j);
        %     tA_norm=myNorm(i);
        %     tB_norm=myNorm(j);
        %     a(1)=a(1)*Kn_norm/tA_norm;
        %     a(2)=a(2)*Kn_norm/tB_norm;
        %     flag=1;
        % elseif(~flag&&counter==1)
        %     for i=1:nf-1
        %         tA=myBases(i,:)';
        %         tA_norm=myNorm(i);
        %         for j=i+1:nf
        %             tB=myBases(j,:)';
        %             tB_norm=myNorm(j);
        %             if(abs(det([tA tB]))>1e-9)
        %                 temp_a=[tA tB]\(Kn_unit);
        %                 temp_a(abs(temp_a)<1e-9)=0;
        %                 if(sum(temp_a)>=0)
        %                     faceA=theFaces(i);
        %                     faceB=theFaces(j);
        %                     a=temp_a;
        %                     a(1)=a(1)*Kn_norm/tA_norm;
        %                     a(2)=a(2)*Kn_norm/tB_norm;
        %                     flag=1;break;
        %                 end
        %             end
        %         end
        %         if(flag),break;end
        %     end
        % end
        %
        % if(~flag)
        %     error(['Decomposition failed for cell ',num2str(c)]);
        % end
        % end
        %
        % function [a,faceA,faceB,faceC]=findABC(G,interpFace,c,Kn)
        % x1=G.cells.centroids(c,:)';
        % theFaces=G.cells.faces(G.cells.facePos(c):G.cells.facePos(c+1)-1,1);
        % myBases=interpFace.coords(theFaces,:);
        % myBases=bsxfun(@minus,myBases,x1');
        % myNorm=sqrt(dot(myBases,myBases,2));
        % myBases=bsxfun(@rdivide,myBases,myNorm);
        % Kn_norm=norm(Kn);
        % Kn_unit=Kn/Kn_norm;
        % myangles=bsxfun(@times,myBases,Kn_unit');
        % myangles=sum(myangles,2);
        % myangles=acos(myangles);
        % [~,I]=sort(myangles);
        % theFaces=theFaces(I);
        % myBases=myBases(I,:);
        % myNorm=myNorm(I);
        % nf=numel(theFaces);
        % flag=0;
        %
        % myIndex=zeros(nf*(nf-1)*(nf-2)/6,3);
        % myCoeff=myIndex;counter=1;
        % for i=1:nf-2
        %     tA=myBases(i,:)';
        %     tA_norm=myNorm(i);
        %     for j=i+1:nf-1
        %         tB=myBases(j,:)';
        %         tB_norm=myNorm(j);
        %         for k=j+1:nf
        %             tC=myBases(k,:)';
        %             tC_norm=myNorm(k);
        %             if(abs(det([tA tB tC]))>1e-9)
        %                 temp_a=[tA tB tC]\(Kn_unit);
        %                 temp_a(abs(temp_a)<1e-9)=0;
        %                 if(all(temp_a>=0))
        %                     if(all(temp_a<=1))
        %                         faceA=theFaces(i);
        %                         faceB=theFaces(j);
        %                         faceC=theFaces(k);
        %                         a=temp_a;
        %                         a(1)=a(1)*Kn_norm/tA_norm;
        %                         a(2)=a(2)*Kn_norm/tB_norm;
        %                         a(3)=a(3)*Kn_norm/tC_norm;
        %                         flag=1;break;
        %                     else
        %                         myIndex(counter,:)=[i,j,k];
        %                         myCoeff(counter,:)=temp_a;
        %                         counter=counter+1;
        %                     end
        %                 end
        %             end
        %         end
        %         if(flag),break;end
        %     end
        %     if(flag),break;end
        % end
        % if(~flag&&counter>1)
        %     myIndex(counter:end,:)=[];myCoeff(counter:end,:)=[];
        %     maxCoeff=max(myCoeff,[],2);
        %     [~,ind]=min(maxCoeff);
        %     i=myIndex(ind,1);j=myIndex(ind,2);k=myIndex(ind,3);
        %     a=myCoeff(ind,:);
        %     faceA=theFaces(i);faceB=theFaces(j);faceC=theFaces(k);
        %     tA_norm=myNorm(i);
        %     tB_norm=myNorm(j);
        %     tC_norm=myNorm(k);
        %     a(1)=a(1)*Kn_norm/tA_norm;
        %     a(2)=a(2)*Kn_norm/tB_norm;
        %     a(3)=a(3)*Kn_norm/tC_norm;
        %     flag=1;
        % elseif(~flag&&counter==1)
        %     for i=1:nf-2
        %         tA=myBases(i,:)';
        %         tA_norm=myNorm(i);
        %         for j=i+1:nf-1
        %             tB=myBases(j,:)';
        %             tB_norm=myNorm(j);
        %             for k=j+1:nf
        %                 tC=myBases(k,:)';
        %                 tC_norm=myNorm(k);
        %                 if(abs(det([tA tB tC]))>1e-9)
        %                     temp_a=[tA tB tC]\(Kn_unit);
        %                     temp_a(abs(temp_a)<1e-9)=0;
        %                     if(sum(temp_a)>0)
        %                         faceA=theFaces(i);
        %                         faceB=theFaces(j);
        %                         faceC=theFaces(k);
        %                         a=temp_a;
        %                         a(1)=a(1)*Kn_norm/tA_norm;
        %                         a(2)=a(2)*Kn_norm/tB_norm;
        %                         a(3)=a(3)*Kn_norm/tC_norm;
        %                         flag=1;break;
        %                     end
        %                 end
        %             end
        %             if(flag),break;end
        %         end
        %         if(flag),break;end
        %     end
        % end
        % if(~flag)
        %     error(['Decomposition failed for cell ',num2str(c)]);
        % end
        % end
       
    end
end
