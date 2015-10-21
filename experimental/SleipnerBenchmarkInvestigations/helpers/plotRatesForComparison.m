function plotRatesForComparison()


    % For plotting injection rates into figures
    
    

        % See Singh et al 2010 for more info about how they determined
        % these rates. Note: the injection rates were reported as surface
        % rates in meters per day. Yearly injection rate in terms of mass
        % (kg) was also given, thus CO2 density at surface is computed as
        % 1.87 kg/m3.
        % CO2 density was reported as 760 kg/m3 for reservoir conditions.
        rhoCO2_surf = 1.87;
        rhoCO2_reservoir = 760;
        
        inj_year_ieaghg   = [1999; 2000; 2001; 2002; 2003; 2004; 2005; 2006; 2007; 2008; 2009];
        inj_rates_ieaghg  = [2.91e4; 5.92e4; 6.35e4; 8.0e4; 1.09e5; 1.5e5; 2.03e5; 2.69e5; 3.47e5; 4.37e5; 5.4e5] .* meter^3/day;
        % inj_rates is in meter^3/s
        
        % convert surface volume rate to reservoir volume rate
        inj_rates_ieaghg  = inj_rates_ieaghg.*rhoCO2_surf/rhoCO2_reservoir; 
        
        

        % See "Injection rates Layer 9.xls" under
        % co2lab/data/sleipner/original for more info about these rates
        [ inj_year_prelim, inj_rates_prelim ] = getSleipnerOriginalInjectionRates();
        % these are the reservoir volume rates, in meter^3/s
                 
        
        
        % plot reservoir volume rates (in m3/year)
        figure; set(gcf,'Position',[1 1 660 350])
        plot(   inj_year_prelim, inj_rates_prelim, 'o', ...
                inj_year_ieaghg, inj_rates_ieaghg, 'x')
        axis tight;
        ylabel('Reservoir rate (m^3/year)')
        xlabel('Year')
        
        % add legend
        hl = legend('GHGT rates','IEAGHG rates');
        set(hl,'Location','northwest')
        
        % adjust axis ticks
        hax = gca;
        set(hax, 'Fontsize',14);
        set(hax.Children(:), 'MarkerSize', 8, 'LineWidth', 2)
        set(hax, 'XLim', [1999 2030])
        set(hax, 'XTick',[1999 hax.XTick(2:end)])
        set(hax, 'YLim', [0 max(inj_rates_prelim)])
        numYticks = 6;
        set(hax, 'YTick',[0 hax.YTick(end)/numYticks:hax.YTick(end)/numYticks:hax.YTick(end)])
        grid;
        
        
        % plot mass rates (converted depending on reservior rhoCO2 given)
        % note: mass rate is same at surface and at reservoir.
        figure; set(gcf,'Position',[1 1 660 350])
        rhoCO2a = 760;      % from SPE paper (Singh et al 2010)
        rhoCO2b = 695.89;   % from prelim benchmark rates (.xls)
        rhoCO2c = 355;      % from Cavanagh et al 2014, table 2
        plot(   inj_year_prelim, inj_rates_prelim.*rhoCO2b, 'o', ...
                inj_year_ieaghg, inj_rates_ieaghg.*rhoCO2a, 'x', ...
                inj_year_prelim, inj_rates_prelim.*rhoCO2c, 'o-.', ...
                inj_year_ieaghg, inj_rates_ieaghg.*rhoCO2c, 'x-.' )
        %ylabel({'Reservoir and Surface';'rate (kg/year)'})
        ylabel({'Mass rate (kg/year) determined from';'CO_2 density at reservoir conditions'})
        xlabel('Year')
        
        % add legend
        hl = legend( ['GHGT rates, CO_2 density=',num2str(rhoCO2b)],['IEAGHG rates, CO_2 density=',num2str(rhoCO2a)], ...
                     ['GHGT rates, CO_2 density=',num2str(rhoCO2c)],['IEAGHG rates, CO_2 density=',num2str(rhoCO2c)]  );
        set(hl,'Location','northwest');

        % adjust axis ticks
        hax = gca;
        set(hax, 'Fontsize',14);
        set(hax.Children(:), 'MarkerSize', 8, 'LineWidth', 2)
        set(hax, 'XLim', [1999 2030])
        set(hax, 'Fontsize',14);
        set(hax.Children(:), 'MarkerSize', 8, 'LineWidth', 2)
        set(hax, 'XLim', [1999 2030])
        set(hax, 'XTick',[1999 hax.XTick(2:end)])
        grid;
        
        
        
        % optional:
        % rates converted into mass/year, depending on rhoCO2 given
        figure
        rhoCO2a = 760;      % from SPE paper (Singh et al 2010)
        rhoCO2b = 695.89;   % from prelim benchmark rates (.xls)
        rhoCO2c = 355;      % from Cavanagh et al 2014, table 2
        plot(   inj_year_prelim, inj_rates_prelim.*rhoCO2a, 'o', ...
                inj_year_ieaghg, inj_rates_ieaghg.*rhoCO2a, 'x', ...
                inj_year_prelim, inj_rates_prelim.*rhoCO2b, 'o--', ...
                inj_year_ieaghg, inj_rates_ieaghg.*rhoCO2b, 'x--', ...
                inj_year_prelim, inj_rates_prelim.*rhoCO2c, 'o-.', ...
                inj_year_ieaghg, inj_rates_ieaghg.*rhoCO2c, 'x-.' )
        ylabel('Reservoir rate, kg/year')
        xlabel('Year')
        legend( ['GHGT rates, CO2 density=',num2str(rhoCO2a)],['IEAGHG rates, CO2 density=',num2str(rhoCO2a)], ...
                ['GHGT rates, CO2 density=',num2str(rhoCO2b)],['IEAGHG rates, CO2 density=',num2str(rhoCO2b)], ...
                ['GHGT rates, CO2 density=',num2str(rhoCO2c)],['IEAGHG rates, CO2 density=',num2str(rhoCO2c)]  )
    
    
    


end

