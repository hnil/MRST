function dt = spe1_dt
%Return sequence of step sizes derived from ECLIPSE/IMPES on SPE1 problem
%
% SYNOPSIS:
%   dt = spe1_dt
%
% PARAMETERS:
%   None.
%
% RETURNS:
%   dt - Vector of step sizes, measured in days, derived from an ECLIPSE
%        run on the 'ODEH.DATA' set using the 'IMPES' option.  Function
%        'convertFrom' may be used to convert the time step sizes into
%        MRST's internal units of time measurement (second).
%
% SEE ALSO:
%   convertFrom, day.


dt = [
     2.343050986528397e-01; ...
     1.392808407545090e-01; ...
     1.840163469314575e-01; ...
     2.188531756401062e-01; ...
     2.235445380210876e-01; ...
     3.141570091247559e-01; ...
     3.821821212768555e-01; ...
     4.804873466491699e-01; ...
     5.964925289154053e-01; ...
     7.461340427398682e-01; ...
     9.976029396057129e-01; ...
     1.308739662170410e+00; ...
     1.576038360595703e+00; ...
     1.927155017852783e+00; ...
     2.371501922607422e+00; ...
     1.649754524230957e+00; ...
     1.649754524230957e+00; ...
     3.901655197143555e+00; ...
     4.884321212768555e+00; ...
     5.967906951904297e+00; ...
     5.123058319091797e+00; ...
     5.123058319091797e+00; ...
     7.964538574218750e+00; ...
     8.175407409667969e+00; ...
     4.430027008056641e+00; ...
     4.430027008056641e+00; ...
     1.043792724609375e+01; ...
     7.281036376953125e+00; ...
     7.281036376953125e+00; ...
     1.136634826660156e+01; ...
     6.816825866699219e+00; ...
     6.816825866699219e+00; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     1.250000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     2.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     2.000000000000000e+01; ...
     1.300000000000000e+01; ...
     1.300000000000000e+01; ...
     1.300000000000000e+01; ...
     1.300000000000000e+01; ...
     1.300000000000000e+01; ...
     1.300000000000000e+01; ...
     1.300000000000000e+01; ...
     1.400000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.000000000000000e+01; ...
     1.250000000000000e+01; ...
     8.500000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     5.000000000000000e+00; ...
     1.000000000000000e+01; ...
];
