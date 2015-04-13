classdef TwoPhaseUpscaler < OnePhaseUpscaler
%Two phase upscaling

properties
    method
    nrelperm
    pcow
    npcow
end

methods
    
    function upscaler = TwoPhaseUpscaler(G, rock, fluid, varargin)
        upscaler = upscaler@OnePhaseUpscaler(G, rock, 'fluid', fluid);
        
        upscaler.method   = [];
        upscaler.nrelperm = 20;
        upscaler.pcow     = true; % Upscale pcow or not
        upscaler.npcow    = 100;
        upscaler = merge_options(upscaler, varargin{:});
    end
       
    function [data, report] = upscaleBlock(upscaler, block)
        
        wantReport = nargout > 1;
        startTime  = tic;
        
        % Perform one phase upscaling first
        [data, rep] = upscaleBlock@OnePhaseUpscaler(upscaler, block);
        if wantReport
            report.onephase = rep;
        end
        
        % Capillary pressure upscaling
        if upscaler.pcow
            [data, rep] = upPcOW(block, data, ...
                'npointsmax', upscaler.npcow);
            if wantReport
                report.pcow = rep;
            end
            if upscaler.verbose
                fprintf('  Cap.pres:     %6.3fs\n', rep.time);
            end
        end
        
        % Relative permeability upscaling
        [data, rep] = upRelPerm(block, data, upscaler.method, ...
            'nvalues', upscaler.nrelperm, 'dims', upscaler.dims, ...
            'dp', upscaler.dp);
        if wantReport
            report.relperm = rep;
        end
        if upscaler.verbose
            fprintf('  Rel.perm:     %6.3fs\n', rep.time);
        end
        
        if wantReport
            totalTime   = toc(startTime);
            report.time = totalTime;
        end
        
    end
    
end

end


