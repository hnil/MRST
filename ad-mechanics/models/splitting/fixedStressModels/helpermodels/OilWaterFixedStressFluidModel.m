classdef OilWaterFixedStressFluidModel < TwoPhaseOilWaterModel
%
%
% SYNOPSIS:
%   model = OilWaterFixedStressFluidModel(G, rock, fluid, varargin)
%
% DESCRIPTION: This model handles the fluid equations of the splitting scheme
% and setup a two phase oil water fluid model. The model is used in the fixed stress splitting
% model.
%
% PARAMETERS:
%   G        - Grid
%   rock     - rock structure
%   fluid    - fluid structure
%   varargin -
%
% RETURNS:
%   class instance
%
% EXAMPLE: run2DCase, runNorneExample
%
% SEE ALSO: TwoPhaseOilWaterModel, MechFluidFixedStressSplitModel, MechFluidSplitModel
%
%
%{
Copyright 2009-2017 SINTEF ICT, Applied Mathematics.

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

    methods
        function model = OilWaterFixedStressFluidModel(G, rock, fluid, varargin)
            model = model@TwoPhaseOilWaterModel(G, rock, fluid);
            model = merge_options(model, varargin{:});
        end

        function [problem, state] = getEquations(model, state0, state, dt, ...
                                                        drivingForces, varargin)
            % Setup the equations for the fluid. The drivingForce contains
            % the volumetric changes computed from the mechanical equations.

            opt = struct('Verbose', mrstVerbose, ...
                         'reverseMode', false,...
                         'resOnly', false,...
                         'iteration', -1);  % Compatibility only

            opt = merge_options(opt, varargin{:});

            [p, sW, wellSol] = model.getProps(state, 'pressure', 'sw', 'wellsol');
            [p0, sW0] = model.getProps(state0, 'pressure', 'sw');
            [wellVars, wellVarNames, wellMap] = ...
                model.FacilityModel.getAllPrimaryVariables(wellSol);

            if ~opt.resOnly,
                [p, sW, wellVars{:}] = initVariablesADI(p, sW, wellVars{:});
            end

            fnew         = drivingForces.fixedStressTerms.new;
            mechTerm.new = fnew.sTerm + fnew.pTerm.*p;
            fold         = drivingForces.fixedStressTerms.old;
            mechTerm.old = fold.sTerm + fold.pTerm.*p0;

            otherDrivingForces = rmfield(drivingForces, 'fixedStressTerms');

            [eqs, names, types, state] = equationsOilWaterMech(p0, sW0, state0, ...
                                                              p, sW, wellVars, ...
                                                              state, model, ...
                                                              dt, mechTerm, ...
                                                              otherDrivingForces, ...
                                                              'iteration', ...
                                                              opt.iteration);

            primaryVars = {'pressure', 'sw', wellVarNames{:}};

            problem = LinearizedProblem(eqs, types, names, primaryVars, state, dt);

        end

        function forces = getValidDrivingForces(model)
            forces = getValidDrivingForces@TwoPhaseOilWaterModel(model);
            % divergence term
            % struct mechTerm.new and mechTerm.old
            forces.fixedStressTerms = [];
        end

        function fds = getAllVarsNames(model)
        % list of all the variable names that are used by this fluid model.
            fds = {'wellSol', 'pressure', 's'};
        end

    end

end
