function mpfastruct = computeMultiPointTrans2(G, rock, varargin)
%Compute multi-point transmissibilities.
%
% SYNOPSIS:
%   T = computeMultiPointTrans2(G, rock)
%
% REQUIRED PARAMETERS:
%   G       - Grid data structure as described by grid_structure.
%
%   rock    - Rock data structure with valid field 'perm'.  The
%             permeability is assumed to be in measured in units of
%             metres squared (m^2).  Use function 'darcy' to convert from
%             (milli)darcies to m^2, e.g.,
%
%                 perm = convertFrom(perm, milli*darcy)
%
%             if the permeability is provided in units of millidarcies.
%
%             The field rock.perm may have ONE column for a scalar
%             permeability in each cell, TWO/THREE columns for a diagonal
%             permeability in each cell (in 2/3 D) and THREE/SIX columns
%             for a symmetric full tensor permeability.  In the latter
%             case, each cell gets the permeability tensor
%
%                 K_i = [ k1  k2 ]      in two space dimensions
%                       [ k2  k3 ]
%
%                 K_i = [ k1  k2  k3 ]  in three space dimensions
%                       [ k2  k4  k5 ]
%                       [ k3  k5  k6 ]
%
% OPTIONAL PARAMETERS
%   verbose   - Whether or not to emit informational messages throughout the
%               computational process.  Default value depending on the
%               settings of function 'mrstVerbose'.
%
%   invertBlocks -
%               Method by which to invert a sequence of small matrices that
%               arise in the discretisation.  String.  Must be one of
%                  - MATLAB -- Use an function implemented purely in MATLAB
%                              (the default).
%
%                  - MEX    -- Use two C-accelerated MEX functions to
%                              extract and invert, respectively, the blocks
%                              along the diagonal of a sparse matrix.  This
%                              method is often faster by a significant
%                              margin, but relies on being able to build
%                              the required MEX functions.
%
% RETURNS:
%  
%   mpfastruct with fields:
%
%               'iB'  : inverse of scalar product (facenode degrees of freedom)
%               'div' : divergence operator (facenode values to cell values)
%               'Pext': projection operator on external facenode values. It
%                       is signed and return boundary outfluxes (positive if exiting).
%               'F'   : flux operator (from cell and external facenode values to facenode values)
%               'A'   : system matrix (cell and external facenode degrees of freedom)
%               'tbls': table structure
   
% COMMENTS:
%   PLEASE NOTE: Face normals have length equal to face areas.
%
% SEE ALSO:
%   `incompMPFAbc`, `mrstVerbose`.

%{
Copyright 2009-2018 SINTEF Digital, Mathematics & Cybernetics.

This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

MRST is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MRST is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MRST.  If not, see <http://www.gnu.org/licenses/>.
%}


   opt = struct('verbose'      , mrstVerbose, ...
                'blocksize'    , []         , ...
                'ip_compmethod', 'general'  , ...
                'invertBlocks' , 'matlab'   , ...
                'eta'          , 0);

   opt = merge_options(opt, varargin{:});
   % possible options for ip_compmethod
   % 'general'       : general case, no special requirements on corner
   % 'nicecorner'    : case where at each corner, number of faces is equal to G.griddim
   % 'directinverse' : case where at each corner, number of faces is equal to
   %                   G.griddim AND eta is value such that N*R is diagonal (see Lipnikov paper)
   
   opt = merge_options(opt, varargin{:});
   switch opt.ip_compmethod
     case {'general', 'nicecorner'}
     case 'directinverse'
       isOk = false;
       if (G.griddim == 2) & (opt.eta == 1/3), isOk = true, end
       if (G.griddim == 3) & (opt.eta == 1/4), isOk = true, end
       if ~isOk
           error(['option values for ip_compmethod and eta are not ' ...
                  'compatible']);
       end
     otherwise
       error('value of option nodeompcase is not recognized.');
   end

   opt.invertBlocks = blockInverter(opt);
   blocksize = opt.blocksize;

   if opt.verbose
       fprintf('Computing inner product on sub-half-faces ... ');
       t0 = tic();
   end

   [B, tbls] = robustComputeLocalFluxMimetic(G, rock, opt);
   facenodetbl = tbls.facenodetbl;
   celltbl = tbls.celltbl;
   
   % if we know - a priori - that matrix is symmetric, then we remove
   % symmetry loss that has been introduced in assembly.
   if strcmp(opt.ip_compmethod, 'directinverse')
       B = 0.5*(B + B');
   end
   
   if opt.verbose
       t0 = toc(t0);
       fprintf('%g sec\n', t0);
   end
   
   if opt.verbose
       fprintf('Computing inverse mixed innerproduct... ');
       t0 = tic();   
   end
   
   %% Invert matrix B
   % The facenode degrees of freedom, as specified by the facenodetbl table, are
   % ordered by nodes first (see implementation below). It means in particular
   % that the matrix B is, by construction, block diagonal.
   nodes = facenodetbl.get('nodes');
   [~, sz] = rlencode(nodes); 
   iB = opt.invertBlocks(B, sz);

   if opt.verbose
       t0 = toc(t0);   
       fprintf('%g sec\n', t0);
   end
   % if we know - a priori - that matrix is symmetric, then we remove the loss of
   % symmetry that may have been introduced by the numerical inversion.
   if strcmp(opt.ip_compmethod, 'directinverse')
       iB = 0.5*(iB + iB');
   end
   
   %% Assemble of the divergence operator, from facenode values to cell value.
   cellnodefacetbl = tbls.cellnodefacetbl;
   
   fno = cellnodefacetbl.get('faces');
   cno = cellnodefacetbl.get('cells');
   sgn = 2*(cno == G.faces.neighbors(fno, 1)) - 1;
   
   prod = TensorProd();
   prod.tbl1 = cellnodefacetbl;
   prod.tbl2 = facenodetbl;
   prod.tbl3 = celltbl;   
   prod.reducefds = {'nodes', 'faces'};
   prod = prod.setup();
   
   div_T = SparseTensor();
   div_T = div_T.setFromTensorProd(sgn, prod);
   div = div_T.getMatrix();

   
   %% Assemble the projection operator from facenode values to facenode values
   % on the external faces.
   
   extfaces = (G.faces.neighbors(:, 1) == 0) | (G.faces.neighbors(:, 2) == 0);
   faceexttbl.faces = find(extfaces);
   faceexttbl = IndexArray(faceexttbl);
   extfacenodetbl = crossIndexArray(facenodetbl, faceexttbl, {'faces'});
   
   map = TensorMap();
   map.fromTbl = cellnodefacetbl;
   map.toTbl = extfacenodetbl;
   map.mergefds = {'faces', 'nodes'};
   map = map.setup();
   
   efn_sgn = map.eval(sgn);
   
   prod = TensorProd();
   prod.tbl1 = extfacenodetbl;
   prod.tbl2 = facenodetbl;
   prod.tbl3 = extfacenodetbl;
   prod.mergefds = {'faces', 'nodes'};
   prod = prod.setup();
   
   Pext_T = SparseTensor();
   Pext_T = Pext_T.setFromTensorProd(efn_sgn, prod);
   Pext = Pext_T.getMatrix();
   
   extfacenodetbl = extfacenodetbl.addLocInd('extfnind');
   tbls.extfacenodetbl = extfacenodetbl;
   
   %% Assemble the flux operator: From pressure values at the cell center and
   % at the external facenode, compute the fluxes at the faces
   F1 = iB*div';
   F2 = - iB*Pext';
   F  = [F1, F2];
   facetbl.faces = (1 : G.faces.num)';
   facetbl = IndexArray(facetbl);
   
   map = TensorMap();
   map.fromTbl = facenodetbl;
   map.toTbl = facetbl;
   map.mergefds = {'faces'};
   map = map.setup();
   
   Aver_T = SparseTensor();
   Aver_T = Aver_T.setFromTensorMap(map);
   Aver = Aver_T.getMatrix();
   
   F = Aver*F;
   
   %% Assemble the system matrix operaror: The degrees of freedom are the pressure
   % values at the cell center and at the external facenode.
   %
   % We have u = iB*div'*p - iB*Pext'*pe
   % where pe is pressure at external facenode.
   %
   
   A11 = div*iB*div';
   A12 = -div*iB*Pext';
   A21 = -Pext*iB*div';
   A22 = Pext*iB*Pext';
   A = [[A11, A12]; [A21, A22]];

   % The first equation row (that is [A11, A12]) corresponds to mass conservation and
   % should equal to source term.
   % The second equation row (that is [A11, A12]) corresponds to definition of external
   % flux and should equal -Pext*u, that is boundary facenode fluxes in
   % inward direction (see definition on Pext: Pext*u returns outward fluxes).
   mpfastruct = struct('div' , div , ...
                       'F'   , F   , ...
                       'A'   , A   , ...
                       'tbls', tbls);
   
end

