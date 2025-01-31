function [info, present] = dataset_npd_frigg()
% Info function for the Norwegian Offshore Directorate Frigg dataset
%
% Use getDatasetInfo or getAvailableDatasets for practical purposes.

%{
Copyright 2009-2024 SINTEF Digital, Mathematics & Cybernetics.

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
        'name', 'NPD_Frigg', ...
        'website', 'https://www.sodir.no/fakta/co2-handtering-ccs/lagringsmodeller/', ...
        'fileurl', 'https://www.sodir.no/globalassets/1-sodir/fakta/co-to/lagringsmodeller/nordsjoen/frigg.zip', ...
        'hasGrid', true, ...
        'hasRock', true, ...
        'hasFluid', true, ...
        'cells',   nan, ...
        'examples', {}, ...
        'description', ['North Sea CO2 storage model from the ', ...
                        'Norwegian Offshore Directorate ', ...
                        '(Sokkeldirektoratet)'], ...
        'filesize',    42.7, ...
        'modelType', 'Eclipse deck (CO2STORE).', ...
        'note', dataset_notes() ...
        );
end

%--------------------------------------------------------------------------

function note = dataset_notes()
   note = { ...
      'Additional Actions Before First Use:'; ...
      '  - Add (append) terminating slash (''/'') character to'; ...
      '      1 ''Jan'' 2010'; ...
      '    record of ''DATES'' keyword starting on line 748 of'; ...
      '    input file ''CO2INJ8W3.DATA''.'; ...
      ''; ... % Blank line
      '  - Remove single quote ('') character from text'; ...
      '      Jan.''02'; ...
      '    at end of line 297 of input file ''CO2INJ8W3.DATA''.' ...
      };
end
