function amg_opt = getAMGCLMexStruct(varargin)
%Undocumented Utility Function

%{
Copyright 2009-2020 SINTEF Digital, Mathematics & Cybernetics.

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

    amg_opt = struct('preconditioner', 'amg', ...
                     'coarsening',     'aggregation', ...
                     'relaxation',     'spai0', ...
                     's_relaxation',   'ilu0', ...
                     'solver',         'gmres', ...
                     'block_size',     0, ...
                     'active_rows',    0, ...
                     'use_drs',        false, ...
                     'drs_eps_ps',     0.02, ...
                     'drs_eps_dd',     0.2, ...
                     'drs_row_weights', [], ...
                     'update_sprecond', false, ...
                     'update_ptransfer', false, ...
                     'cpr_blocksolver', true, ...
                     'coarse_enough',  -1, ...
                     'direct_coarse',  true, ...
                     'max_levels',     -1, ...
                     'ncycle',         1, ...
                     'npre',           1, ...
                     'npost',          1, ...
                     'pre_cycles',     1, ...
                     'gmres_m',        30, ...
                     'lgmres_k',        3, ...
                     'lgmres_always_reset', true,  ...
                     'lgmres_store_av',  true, ...
                     'idrs_s',           4, ...
                     'idrs_omega',       0.7, ...
                     'idrs_replacement', false, ...
                     'bicgstabl_l',      2, ...
                     'bicgstabl_delta',  0, ...
                     'bicgstabl_convex', true, ...
                     'aggr_eps_strong',  0.08, ...
                     'aggr_over_interp', 1.0, ...
                     'rs_eps_strong',    0.25, ...
                     'rs_trunc',         true, ...
                     'rs_eps_trunc',     0.2, ...
                     'aggr_relax',       2.0/3.0, ...
                     'write_params',     false, ...
                     'nthreads',         maxNumCompThreads(), ...
                     'verbose',          false);
    relax_opt = {'ilut_p',           2; ...
                 'ilut_tau',         0.01; ...
                 'iluk_k',           1; ...
                 'ilu_damping',      1; ...
                 'jacobi_damping',   0.72; ...
                 'chebyshev_degree', 5; ...
                 'chebyshev_lower',  1.0/30; ...
                 'chebyshev_power_iters', 0};
    for i = 1:size(relax_opt, 1)
        name = relax_opt{i, 1};
        val = relax_opt{i, 2};
        amg_opt.(name) = val;
        amg_opt.(['s_', name]) = val;
    end
 
    amg_opt = merge_options(amg_opt, varargin{:});
    % Translate into codes
    amg_opt.preconditioner = translateOptionsAMGCL('preconditioner', amg_opt.preconditioner);
    amg_opt.coarsening = translateOptionsAMGCL('coarsening', amg_opt.coarsening);
    amg_opt.relaxation = translateOptionsAMGCL('relaxation', amg_opt.relaxation);
    amg_opt.s_relaxation = translateOptionsAMGCL('relaxation', amg_opt.s_relaxation);
    amg_opt.solver = translateOptionsAMGCL('solver', amg_opt.solver);
end
