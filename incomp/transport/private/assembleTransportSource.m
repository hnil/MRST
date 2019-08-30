function q = assembleTransportSource(state, fluid, q, nc, varargin)
%Form source term vector from individual contributions
%
% SYNOPSIS:
%   q = assembleTransportSource(state, fluid, q, nc)
%   q = assembleTransportSource(state, fluid, q, nc, 'pn1', pv1, ...)
%
% PARAMETERS:
%   state   - State object
%
%   fluid   - Fluid object
%
%   q       - Individual source and sink terms as generated by
%             computeTransportSourceTerm.
%
%   nc      - Size (number of elements) of resulting source term vector.
%             Typically corresponds to 'cells.num' of a grid_structure.
%
%   'pn'/pv - List of 'key'/value pairs defining optional parameters.  The
%             supported options are:
%               - use_compi --
%                   Whether or not to include the composition of injected
%                   fluids into the source term.  This is appropriate for
%                   two-phase flow only, and simply scales the rate of
%                   fluid sources with component one of 'q.compi'.  Sinks,
%                   i.e, those terms for which the source rate is negative,
%                   remain unaffected.
%
%                   LOGICAL.  Default value: use_compi=TRUE (include
%                   composition of injected fluid into fluid sources).
%
% RETURNS:
%   q - Source term vector.  An nc-by-1 (sparse) vector of accumulated
%       source terms.
%
% SEE ALSO:
%   `private/computeTransportSourceTerm`.

   opt = struct('use_compi', true);
   opt = merge_options(opt, varargin{:});

   check_input(q, nc, opt)

   if opt.use_compi && ~all(structfun(@isempty, q))
      % This problem features source terms (i.e., not a purely
      % gravity-driven problem) and the caller requests scaling injection
      % sources by "water" saturations.

      i   = q.flux > 0;
      if isfield(state, 'pressure')
          p_cell = state.pressure(q.cell);
      else
          p_cell = repmat(1*atm, numel(q.cell));
      end
      tmpstate = struct('pressure', p_cell, ...
                        's', q.compi);
      [tmp, kr, mu]= getIncompProps(tmpstate, fluid); %#ok<ASGLU>
      clear tmp
      m   = bsxfun(@rdivide, kr, mu);
      f   = m(:,1) ./ sum(m,2);
      q.flux(i) = q.flux(i) .* f(i);
   end

   q = sparse(q.cell, 1, q.flux, nc, 1);
end

%--------------------------------------------------------------------------

function check_input(q, nc, opt)
   [i, p] = deal(false([nc, 1]));

   i(q.cell(q.flux > 0)) = true;
   p(q.cell(q.flux < 0)) = true;

   assert (~ any(i & p), ...
           'MRST does not support injection and production in same cell');

   assert (~ (opt.use_compi && (isempty(q.compi) ~= isempty(q.cell))), ...
           'Must specify injection composition when solving transport');

   assert (numel(q.cell) == numel(q.flux), ...
           'There must be one rate for each transport source term');

   if opt.use_compi
      assert (size(q.compi, 1) == numel(q.cell), ...
             ['There must be one injection composition for each ', ...
              'source term when solving transport']);
   end
end
