function [info, present] = dataset_msfractures()
% Info function for MSFractures dataset. Use getDatasetInfo or getAvailableDatasets for practical purposes.

%{
Copyright 2009-2023 SINTEF Digital, Mathematics & Cybernetics.

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
    [info, present] = datasetInfoStruct(...
        'name', 'MSFractures', ...
        'website', '', ...
        'fileurl', 'https://www.sintef.no/contentassets/124f261f170947a6bc51dd76aea66129/MSFractures.zip', ...
        'hasGrid', true, ...
        'hasRock', true, ...
        'hasFluid', false, ...
        'cells',   7932, ...
        'examples', {'msrsb:fracturedExampleCompositionalMS', ...
                     'msrsb:fracturedExampleMS'}, ...
        'description', 'Grid and permeability for example 2 in "A Mass-Conservative Sequential Implicit Multiscale Method for Isothermal Equation Of State Compositional Problems", Moyner & Tchelepi, SPE J, 2018',...
        'filesize',    1.549, ...
        'modelType', 'Just the grid and perm, in MRST format as a .mat file - ' ...
         );
end
