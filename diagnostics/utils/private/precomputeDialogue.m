function [] = precomputeDialogue(casenm, precompDir)
sp = repmat(' ', [1, 8]);
    widestr = @(str)[sp, str, sp];
    
answ = questdlg(sprintf('Precompute diagnostics and write to:                                         \n   %s  \nThis might take up to 30 min',  precompDir), ...
             'Precompute for improved performance', ...
             widestr('OK'), widestr('skip'), widestr('OK'));


if strcmp(answ, widestr('OK'))
    processRestartDiagnostics(casenm, 'outputdir', precompDir);
end
end