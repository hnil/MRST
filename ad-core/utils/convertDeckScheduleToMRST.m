function scheduleMRST = convertDeckScheduleToMRST(model, scheduleDeck, varargin)
% Convert deck-type schedule to MRST style schedule
%
% SYNOPSIS:
%   schedule = convertDeckScheduleToMRST(model, deck.SCHEDULE)
%
% DESCRIPTION:
%   Take a schedule in deck-style (from for example the output of
%   readEclipseDeck), parse all wells and create a new schedule suitable
%   for 'simulateScheduleAD'.
%
% REQUIRED PARAMETERS:
%   G       - Valid grid (likely from initEclipseGrid). Must be the same
%           grid as the wells in the schedule are defined for.
% 
%   rock    - Valid rock used to compute the well indices. Typically from
%             initEclipseRock.
%
%   scheduleDeck - Either a deck struct from readEclipseDeck or the
%                  schedule (typically deck.SCHEDULE).
%
% 
% OPTIONAL PARAMETERS:
%
%   'StepLimit' - Only parse the first n control steps.
%
% RETURNS:
%   scheduleMRST - Schedule ready for simulation in 'simulateScheduleAD'.

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

    opt = struct('StepLimit', inf, ...
                 'EnsureConsistent', true);
    [opt, wellArg] = merge_options(opt, varargin{:});


    if isfield(scheduleDeck, 'RUNSPEC') &&...
       isfield(scheduleDeck, 'SCHEDULE')
       % Support passing deck directly
       scheduleDeck = scheduleDeck.SCHEDULE;
    end
    scheduleMRST = struct('step', scheduleDeck.step);
    
    nc = numel(scheduleDeck.control);
    
    tmp = cell(nc, 1);
    scheduleMRST.control = struct('W', tmp, 'bc', tmp, 'src', tmp);
    
    % Massage phases in compi to match active components in model
    ncomp = numel(model.saturationVarNames);
    map = zeros(ncomp, 1);
    for i = 1:ncomp
        switch lower(model.saturationVarNames{i})
            case 'sw'
                map(i) = 1;
            case 'so'
                map(i) = 2;
            case 'sg'
                map(i) = 3;
            case 'ss'
                map(i) = 3;
                % Solvent injection rate is given as fraction of gas
                % injection rate.
            otherwise
                map(i) = 4;
                warning('Unknown phase, translation directly from deck difficult, setting zero');
        end
    end
    
    for i = 1:nc
        % Parse well
        W = processWells(model.G, model.rock, scheduleDeck.control(i), wellArg{:});
        
        for j = 1:numel(W)
            c = [W(j).compi, 0];
            W(j).compi = c(map);
            if isfield(W(j), 'solventFrac')
                W(j).compi(3) = W(j).compi(3)*(1-W(j).solventFrac);
                W(j).compi(4) = W(j).compi(4)*W(j).solventFrac;
            end
        end
        scheduleMRST.control(i).W = W;
    end
    
    if ~isinf(opt.StepLimit)
        scheduleMRST.step.val     = scheduleMRST.step.val(1:opt.StepLimit);
        scheduleMRST.step.control = scheduleMRST.step.control(1:opt.StepLimit);
    end
    
    if opt.EnsureConsistent
        scheduleMRST = makeScheduleConsistent(scheduleMRST);
    end
end
