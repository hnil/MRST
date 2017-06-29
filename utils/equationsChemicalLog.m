function [eqs, names, types] = equationsChemicalLog(logcomps, logmasterComps, model)

%             comps = cellfun(@(x) x*litre/mol, comps,'UniformOutput', false);
%             masterComps = cellfun(@(x) x*litre/mol, masterComps,'UniformOutput', false);

    try 
        T = model.getProp(state, 'temperature');
    catch
        T = 298;
    end
    An  = 6.0221413*10^23;       	% avagadros number [#/mol]
    F   = 9.64853399e4;             % Faraday's Constant [C/mol]
    R   = 8.3144621;             	% Gas Constant [J/(K mol)]
    e_o = 8.854187817620e-12;       % permitivity of free space [C/Vm]
    e_w = 87.740 - 0.4008.*(T-273.15) + 9.398e-4.*(T-273.15).^2 - 1.410e-6*(T-273.15).^3;% Dielectric constant of water
    A   = 1.82e6*(e_w.*T).^(-3/2);

    RM = model.ReactionMatrix;
    CM = model.CompositionMatrix;

    % Pi = cellfun(@(x) ~isempty(x), regexpi(model.CompNames, 'psi'));
    % RMp = RM(:,Pi');
    % lcp = cell(sum(Pi),1);
    % [lcp{:}] = logcomps{Pi'};

    comps = cellfun(@(x) exp(x), logcomps, 'UniformOutput', false);

    logK = model.LogReactionConstants;

    eqs   = cell(1, model.nR + model.nMC);
    names = cell(1, model.nR + model.nMC);
    types = cell(1, model.nR + model.nMC);

    % calculate activity
    ionDum = 0;
    nP = sum(cellfun(@(x) ~isempty(x), regexpi(model.CompNames, 'psi')));
    model.ChargeVector = [model.ChargeVector, zeros(1,nP)];
    for i = 1 : model.nC
        ionDum = ionDum + (model.ChargeVector(1,i).^2.*comps{i}).*litre/mol;
    end
    ion = cell(1,model.nC);
    [ion{:}] = deal((1/2)*ionDum);

    pg = cell(1,model.nC);
    for i = 1 : model.nC
        pg{i} = log(10).*-A.*model.ChargeVector(1,i)'.^2 .* (ion{i}.^(1/2)./(1 + ion{i}.^(1/2)) - 0.3.*ion{i});
        
%         try 
%             doub = pg{i}.val;
%         catch
%             doub = pg{i};
%         end
%         
%         if sum(doub) == 0 && ~strcmpi(model.CompNames{i}, 'H2O')
%             pg{i} = log(10^0.010)*ones(size(pg{i},1),1);
%         end
    end

    % Reaction matrix, activities only apply to laws of mass action
    for i = 1 : model.nR  
        eqs{i} = -logK(i);
        for k = 1 : model.nC
            eqs{i} = eqs{i} + RM(i, k).*(pg{i} + logcomps{k});
        end
        names{i} = model.rxns{i};
    end

    assert(all(all(CM>=0)), ['this implementation only supports positive ' ...
                        'master components values']);

    for i = 1 : model.nMC
        j = model.nR + i;
        masssum = 0;
        for k = 1 : model.nC
            masssum = masssum + CM(i,k).*comps{k};
        end
        eqs{j} = log(masssum) - logmasterComps{i};
        names{j} = ['Conservation of ', model.MasterCompNames{i}] ;
    end

    if ~isempty(model.surfInfo)

        % figure out what to do with ccm and generally, how to handle all
        % of this
        call = 0;
        for i = 1 : numel(model.surfInfo.master)

            if strcmpi(model.surfInfo.scm{i},'langmuir')
                call = call + 1;
                continue
            end
        
            % grab the correct info
            S = model.surfInfo.s{i}*gram/(meter)^2;
            a = model.surfInfo.a{i}*litre/gram;
            C = model.surfInfo.c{i-call};

            % surface funcitonal group name
            surfName = model.surfInfo.master{i};

            % number of species associated with surface
            nSp = numel(model.surfInfo.species{i});
            SpNames = model.surfInfo.species{i};
            charge = model.surfInfo.charge{i};


            switch model.surfInfo.scm{i}
                case 'tlm'

                    % calculate surface and IHP charge
                    sig_0 = 0;
                    sig_1 = 0;
                    sig_2 = 0;
                    for j = 1 : nSp
                        SpInd = strcmpi(SpNames{j}, model.CompNames);
                            sig_0 = sig_0 + charge{j}(1).*comps{SpInd}.*litre/ ...
                                     mol;
    
                            sig_1 = sig_1 + charge{j}(2).*comps{SpInd}.*litre/ ...
                                     mol;
                                 
                            sig_2 = sig_2 + charge{j}(3).*comps{SpInd}.*litre/ ...
                                     mol;
                    end
                    sig_0 = (F./(S.*a)).*sig_0;
                    sig_1 = (F./(S.*a)).*sig_1;
                    sig_2 = (F./(S.*a)).*sig_2;
                    
                    % diffuse layer charge
                    mysinh = @(x) exp(x)./2 - exp(-x)./2;
%           
                    P2Ind = strcmpi([surfName '_ePsi_2'], model.CompNames);
                    P1Ind = strcmpi([surfName '_ePsi_1'], model.CompNames);
                    P0Ind = strcmpi([surfName '_ePsi_0'], model.CompNames);

                    sig_2 = sig_2 + -(8*10^3*R*T.*ion{end}.*e_o*e_w).^(0.5).*mysinh(logcomps{P2Ind}./2);
                    
                    
                    eqs{end+1} = sig_0 + sig_1 + sig_2;
                    names{end+1} = ['charge balance of ' surfName];
                    types{end+1} = [];
                    
                    
                    eqs{end+1} = -sig_0 + C(:,1).*(R*T)./F.*(logcomps{P0Ind} - logcomps{P1Ind});
                    names{end+1} = ['-s0 + C1*(P0 - P1), ' surfName];
                    types{end+1} = [];
                    
                    
                    eqs{end+1} = -sig_2 - C(:,2).*(R*T)./F.*(logcomps{P1Ind} - logcomps{P2Ind});
                    names{end+1} = ['-s2 - C2*(P1 - P2), ' surfName];
                    types{end+1} = [];

                case 'ccm'

                    % calculate surface charge
                    sig = 0;
                    for j = 1 : nSp
                        SpInd = strcmpi(model.surfInfo.species{i}{j}, model.CompNames);
                        
                            sig = sig + charge{j}.*comps{SpInd}.*litre/ ...
                                     mol;
                        
                    end
                    sig = (F./(S.*a)).*sig;
                    
                    % explicitly calculate what the potential should be

                    Pind = cellfun(@(x) ~isempty(x), regexpi(model.CompNames, [surfName '_']));
                    eqs{end+1} = -sig + (R*T/F).*logcomps{Pind}.*C(:,1);
                    names{end+1} = ['-s + Psi*C ,' surfName];
                    types{end+1} = [];
            end
        end


    end

    [types{:}] = deal('cell');

end
