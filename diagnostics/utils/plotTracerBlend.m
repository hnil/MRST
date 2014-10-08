function varargout = plotTracerBlend(G, partition, maxconc, varargin)
%Visualise tracer partition, with gray areas to represent smearing
%
% SYNOPSIS:
%       plotTracerBlend(G, partition, maxconc)
%       plotTracerBlend(G, partition, maxconc, 'pn1', pv1, ...)
%   h = plotTracerBlend(...)
%
% PARAMETERS:
%   G         - Grid structure partitioned by tracers.
%
%   partition - Tracer partition structure.  This is the field '.ppart' (or
%               '.ipart') of the diagnostics structure constructed by
%               function 'computeTOFandTracer'.  One non-negative
%               (integral) value for each grid cell.
%
%   maxconc   - Maximum tracer concentration.  One scalar value for each
%               grid cell.  This value is typically MAX(D.ptracer, [], 2).
%
%   'pn'/pv   - List of 'key'/value pairs defining optional parameters.
%               The supported options are:
%                  - p --
%                     Power by which to amplify smearing effects.  Note
%                     that the amplification power is applied to a
%                     decreasing function of concentration, so to highlight
%                     regions of smearing, small (but positive) powers
%                     should be used.  Using p = 0.2 works well in the case
%                     of secondary production on the Tarbert layers of
%                     SPE10.
%
%                     Default value: p = 1.  No special highlighting or
%                     amplification of smearing regions.
%
% RETURNS:
%   h - Patch handle as defined by function 'plotCellData'.  Only returned
%       if specifically requested.
%
% EXAMPLES:
%   [G, W, rock] = SPE10_setup(1:10);
%
%   is_pos = rock.poro > 0;
%   rock.poro(~is_pos) = min(rock.poro(is_pos));
%
%   T = computeTrans(G, rock);
%   fluid = initSingleFluid('mu' , 1*centi*poise, ...
%                           'rho', 1000*kilogram/meter^3);
%   state = incompTPFA(initState(G, W, 0), G, T, fluid, 'wells', W);
%   D = computeTOFandTracer(state, G, rock, 'wells', W);
%
%   plotTracerBlend(G, D.ppart, max(D.ptracer, [], 2))
%
%   axis equal tight off, set(gca, 'DataAspectRatio', [ 1, 1, 0.1 ])
%
% SEE ALSO:
%   computeTOFandTracer, plotCellData.

%{
Copyright 2009-2014 SINTEF ICT, Applied Mathematics.

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

   opt  = struct('p', 1);
   opt  = merge_options(opt, varargin{:});

   nreg = max(partition);
   cmap = colorcube(max(nreg, 8));

   p   = opt.p;  if ~ (p > 0), p = 1; end

   w   = min(max(2 * (1 - maxconc), 0), 1);
   bc  = 0.5;
   rgb = bsxfun(@plus, bsxfun(@times, 1 - w.^p, cmap(partition, :)), ...
                w.^p .* bc);

   h = plotCellData(G, rgb);

   if nargout > 0, varargout{1} = h; end
end
