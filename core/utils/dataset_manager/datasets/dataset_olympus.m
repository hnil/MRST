function [info, present] = dataset_olympus()
% Info function for Olympus benchmark dataset. Use getDatasetInfo or getAvailableDatasets for practical purposes.

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

    helper = ['Visit the field optimization challenge website ', ...
              '(free registration required) and place the downloaded files in "',...
              mrstDataDirectory(), '"'];

    [info, present] = datasetInfoStruct(...
        'name', 'Olympus', ...
        'website', 'http://www.isapp2.com/optimization-challenge.html', ...
        'fileurl', '', ...
        'hasGrid', true, ...
        'hasRock', true, ...
        'hasFluid', true, ...
        'cells', 192750, ...
        'instructions', helper , ...
        'examples', { ...
                     }, ...
        'description', ['The Olympus field optimization challenge contains 50', ...
                       ' realizations of the same field model.'], ...
        'modelType', 'Two-phase oil-water, corner-point' ...
         );
end
