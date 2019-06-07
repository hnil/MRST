function regions = getInitializationRegionsDeck(model, deck)
    n = size(deck.SOLUTION.EQUIL, 1);
    model = model.validateModel();

    regions = cell(n, 1);
    for regionIx = 1:n
        % Get all combinations of PVT/SATNUM regions for this block
        if isfield(deck.REGIONS, 'EQLNUM')
            cells = find(deck.REGIONS.EQLNUM(model.G.cells.indexMap) == regionIx);
        else
            cells = (1:model.G.cells.num)';
        end
        eql = deck.SOLUTION.EQUIL(regionIx, :);
        
        sat = getSATNUM(model, deck, cells);
        pvt = getPVTNUM(model, deck, cells);
        
        pairs = unique([sat, pvt], 'rows');
        nreg_comb = size(pairs, 1);
        
        sub_regions = cell(nreg_comb, 1);
        for j = 1:nreg_comb
            satnum = pairs(j, 1);
            pvtnum = pairs(j, 2);
            subcells = cells(sat == satnum & pvt == pvtnum);
            
            sub_regions{j} = getRegion(model, deck, eql, subcells, regionIx, satnum, pvtnum);
        end
        regions{regionIx} = sub_regions;
    end
    % Flatten local regions
    regions = vertcat(regions{:});
end

function reg = getSATNUM(model, deck, cells)
    if isfield(deck.REGIONS, 'SATNUM')
        reg = deck.REGIONS.SATNUM(model.G.cells.indexMap(cells));
    else
        reg = ones(numel(cells), 1);
    end
end


function reg = getPVTNUM(model, deck, cells)
    if isfield(deck.REGIONS, 'PVTNUM')
        reg = deck.REGIONS.PVTNUM(model.G.cells.indexMap(cells));
    else
        reg = ones(numel(cells), 1);
    end
end

function region = getRegion(model, deck, eql, cells, regionIx, satnum, pvtnum)
    rs_method = eql(7);
    rv_method = eql(8);
    contacts = eql([3, 5]);
    contacts_pc = eql([4, 6]);
    p_datum = eql(2);
    if model.water && model.gas && ~model.oil
        act = [true, false, false];
    else
        act = [model.water & model.oil, model.oil & model.gas];
    end
    % Handle specifics
    hasVapoil = isprop(model, 'vapoil') && model.vapoil;
    hasDisgas = isprop(model, 'disgas') && model.disgas;
    hasEOS = isprop(model, 'EOSModel');
    if hasEOS
    end
    
    if hasEOS
        z_method = eql(10);
        assert(z_method == 1);
        zvd = deck.PROPS.ZMFVD{regionIx};
        z_fn = @(p, z) interp1(zvd(:, 1), zvd(:, 2:end), z);
        tvd = deck.PROPS.TEMPVD{regionIx};
        T_fn = @(p, z) interp1(tvd(:, 1), tvd(:, 2), z);

        region = getInitializationRegionsCompositional(model, contacts(act),...
            'cells', cells, 'datum_pressure', p_datum, ...
            'datum_depth', eql(1), 'contacts_pc', contacts_pc(act), ...
            'x', z_fn, 'y', z_fn, 'T', T_fn);
        region.T = T_fn;
        region.z = z_fn;
    else
        region = getInitializationRegionsBlackOil(model, contacts(act),...
            'cells', cells, 'datum_pressure', p_datum, ...
            'datum_depth', eql(1), 'contacts_pc', contacts_pc(act));
    end
    if hasDisgas
        if rs_method <= 0
            rsSat = model.fluid.rsSat;
            if iscell(rsSat)
                rs =  @(p, z) 0*p + model.fluid.rsSat{pvtnum}(p_datum);
            else
                rs =  @(p, z) 0*p + model.fluid.rsSat(p_datum);
            end
        else
            assert(isfield(deck.SOLUTION, 'RSVD'));
            rsvd = deck.SOLUTION.RSVD{regionIx};
            F = griddedInterpolant(rsvd(:, 1), rsvd(:, 2), 'linear', 'nearest');
            rs = @(p, z) F(z);
        end
        region.rs = rs;
    end
    
    if hasVapoil
        if rv_method <= 0
            % Oil pressure at gas-oil contact + capillary pressure there
            pg_goc = p_datum + eql(6);
            rvSat = model.fluid.rvSat;
            if iscell(rvSat)
                rv =  @(p, z) 0*p + model.fluid.rvSat{pvtnum}(pg_goc);
            else
                rv =  @(p, z) 0*p + model.fluid.rvSat(pg_goc);
            end
        else
            assert(isfield(deck.SOLUTION, 'RVVD'));
            rvvd = deck.SOLUTION.RVVD{regionIx};
            F = griddedInterpolant(rvvd(:, 1), rvvd(:, 2), 'linear', 'nearest');
            rv = @(p, z) F(z);
        end
        region.rv = rv;
    end
end
