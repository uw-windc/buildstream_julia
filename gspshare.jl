using GamsStructure
using CSV


function gspshare(;base_set_dir = "base_data_2017/set", 
                   base_parm_dir = "base_data_2017/parameter",
                   national_data_dir ="data/nationaldata_ls_julia",
                   map_path = "maps/mapgsp.csv",
                   output_path = missing)

    GU = load_gspshare_data(set_dir = base_set_dir,
                            parm_dir = base_parm_dir,
                            national_data_dir = national_data_dir)

    mapgsp = load_gspshare_map(map_file = map_path)
    gspshare_create_region_shr!(GU,mapgsp)
    gspshare_create_labor_shr!(GU,mapgsp)

    if !(ismissing(output_path))
        unload(GU,output_path,to_unload = [:yr,:r,:s,:region_shr,:labor_shr])
    end

    return GU
end


function load_gspshare_data(;set_dir = "base_data_2017/set", parm_dir = "base_data_2017/parameter",national_data_dir ="data/nationaldata_ls_julia" )
    GU = GamsUniverse()

    @GamsSets(GU,set_dir,begin
        :yr, "Years in WiNDC Database"
        :sr, "Super Regions in WiNDC Database"
        :r,  "Regions in WiNDC Database"
        :i,  "BEA Goods and sectors categories"
    end)


    alias(GU,:i,:s)
    alias(GU,:i,:j)


    @GamsDomainSets(GU,parm_dir,begin
        :gdpcat, :gsp_units, 3, "Dynamically creates set from parameter gsp_units, GSP components"
        :si,     :gsp_units, 4, "Dynamically created set from parameter gsp_units, State industry list"
        :units,  :gsp_units, 5, "Dynamically creates set from parameter gsp_units, GSP units"
    end)



    @GamsSet(GU,:netva_,"Fourth dimension of netva",begin
        sudo, ""
        comp,""
    end)



    @GamsSet(GU,:comparelshr_,"Third dimension of comparelshr",begin
        bea, ""
        gsp,""
    end)

    @GamsSet(GU,:gsp0_,"Fourth dimension of gsp0",begin
        calculated, ""
        reported,""
        diff,""
    end)


    @GamsParameters(GU,parm_dir,begin
        :gsp_units, (:sr,:yr,:gdpcat,:si,:units), "Annual gross state product with units as domain", [1,2,3,4,5]
    end);


    load_universe!(GU,national_data_dir,to_load = [:va,:va_0])

    @GamsParameters(GU,begin
        :lshr_0,        (:yr,:s),               "Labor share of value added from national dataset"
        :gspcalc,       (:r,:yr,:gdpcat,:si),   "Calculated gross state product"
        :region_shr,    (:yr,:r,:s),            "Regional share of value added";
        :labor_shr,     (:yr,:r,:s),            "Share of regional value added due to labor"
        :netva,         (:yr,:r,:s,:netva_),    "Net value added (compensation + surplus)"
        :comparelshr,   (:yr,:s,:comparelshr_), "Comparison between state and national dataset"
        :seclaborshr,   (:yr,:s),               "Sector level average labor shares"
        :avgwgshr,      (:r,:s),                "Average wage share"
        :chkshrs,       (:yr,:s),               "Check on regional shares"
        :gsp0,          (:yr,:r,:s,:gsp0_),     "Mapped state level gsp accounts"
        :gspcat0,       (:yr,:r,:s,:gdpcat),    "Mapped gsp categorical accounts"
        #:hetersh,       (:ur,:r,:s,*),          "Heterogeneity in labor value added shares"
    end)

    return GU

end


function load_gspshare_map(;map_file ="maps/mapgsp.csv" )

    mapgsp = Dict()
    F = CSV.File(map_file,stringtype=String,
                silencewarnings=true,header = [:a,:b,:c])

    for row in F
        key = Symbol(row[1])
        val = Symbol(string(row[2]))
        mapgsp[key] = val
        #mapgsp[Symbol(string(row[2]))] = Symbol(row[1])
    end
    return mapgsp
end


function gspshare_create_region_shr!(GU,mapgsp)
    S = GU[:s]
    YR = GU[:yr]
    R = [r for r∈GU[:r]]
    SI = GU[:si]


    for yr∈YR,s∈S
        GU[:lshr_0][[yr],[s]] = (GU[:va_0][[yr],[:compen],[s]] + GU[:va_0][[yr],[:surplus],[s]]) != 0 ? 
                            GU[:va_0][[yr],[:compen],[s]] / (GU[:va_0][[yr],[:compen],[s]] + GU[:va_0][[yr],[:surplus],[s]]) : 0
    end


    # Note: GSP <> lab + cap + tax in the data for government affiliated sectors
    # (utilities, enterprises, etc.).


    GU[:gspcalc][R,YR,[:cmp],SI]    = GU[:gsp_units][R,YR,[:cmp],SI,[Symbol("millions of us dollars (USD)")]]
    GU[:gspcalc][R,YR,[:gos],SI]    = GU[:gsp_units][R,YR,[:gos],SI,[Symbol("millions of us dollars (USD)")]]
    GU[:gspcalc][R,YR,[:taxsbd],SI] = GU[:gsp_units][R,YR,[:taxsbd],SI,[Symbol("millions of us dollars (USD)")]]
    GU[:gspcalc][R,YR,[:gdp],SI]    = GU[:gspcalc][R,YR,[:cmp],SI] .+ GU[:gspcalc][R,YR,[:gos],SI] .+ GU[:gspcalc][R,YR,[:taxsbd],SI];


    # Note that some capital account elements of GSP are negative (taxes and
    # capital expenditures).
    
    # -------------------------------------------------------------------
    # Map GSP sectors to national IO definitions:
    # -------------------------------------------------------------------
    
    # Note that in the mapping, aggregate categories in the GSP dataset are
    # removed. Also, the used and other sectors don't have any mapping to the
    # state files. In cases other than used and other, the national files have
    # more detail. In cases where multiple sectors are mapped to the state gdp
    # estimates, the same profile of GDP will be used. Used and scrap sectors
    # are defined by state averages.


    GU[:s][:oth].active = false
    GU[:s][:use].active = false

    GU[:gsp0][:yr,R,:s,[:calculated]]  = permutedims(GU[:gspcalc][R,:yr,[:gdp],[mapgsp[s] for s∈GU[:s]]],(2,1,3))
    GU[:gsp0][:yr,R,:s,[:reported]]    = permutedims(GU[:gsp_units][R,:yr,[:gdp],[mapgsp[s] for s∈GU[:s]],[Symbol("millions of us dollars (USD)")]],(2,1,3))
    GU[:gsp0][:yr,R,:s,[:diff]]        = GU[:gsp0][:yr,R,:s,[:calculated]] - GU[:gsp0][:yr,R,:s,[:reported]]
    GU[:gspcat0][:yr,R,:s,GU[:gdpcat]] = permutedims(GU[:gsp_units][R,:yr,GU[:gdpcat],[mapgsp[s] for s∈GU[:s]],[Symbol("millions of us dollars (USD)")]],(2,1,4,3))



    # For the most part, these figures match (rounding errors produce +-1 on the
    # check). However, sector 10 other government affiliated sectors (utilities)
    # produces larger error.
    
    # -------------------------------------------------------------------
    # Generate io-shares using national data to share out regional GDP
    # estimates, first mapping data to state level aggregation:
    # -------------------------------------------------------------------


    #denominator = sum(GU[:gsp0][:yr,R,:s,[:reported]],dims=2).!=0
    #GU[:region_shr][mask] = (sum(GU[:gsp0][[yr],R,[s],[:reported]])!=0) ?  GU[:gsp0][[yr],[r],[s],[:reported]] / sum(GU[:gsp0][[yr],R,[s],[:reported]]) : 0
    for yr∈YR,r∈R,s∈S
        GU[:region_shr][[yr],[r],[s]] = (sum(GU[:gsp0][[yr],R,[s],[:reported]])!=0) ?  GU[:gsp0][[yr],[r],[s],[:reported]] / sum(GU[:gsp0][[yr],R,[s],[:reported]]) : 0
    end
    
    # Let the used and scrap sectors be an average of other sectors:


    for yr∈YR,r∈R
        GU[:region_shr][[yr],[r],[:use]] = sum(GU[:region_shr][[yr],R,S])!=0 ? sum(GU[:region_shr][[yr],[r],S]) / sum(GU[:region_shr][[yr],R,S]) : 0
        GU[:region_shr][[yr],[r],[:oth]] = sum(GU[:region_shr][[yr],R,S])!=0 ? sum(GU[:region_shr][[yr],[r],S]) / sum(GU[:region_shr][[yr],R,S]) : 0
    end

    # Why are these off in the above?
    GU[:s][:oth].active = true
    GU[:s][:use].active = true
    
    # Verify regional shares sum to one:
    for yr∈YR,r∈R,s∈S
        GU[:region_shr][[yr],[r],[s]] = sum(GU[:region_shr][[yr],R,[s]])!=0 ?  GU[:region_shr][[yr],[r],[s]] / sum(GU[:region_shr][[yr],R,[s]]) : 0
    end
end


function gspshare_create_labor_shr!(GU,mapgsp)

    S = GU[:s]
    YR = GU[:yr]
    R = GU[:r]
    SI = GU[:si]

    # Construct factor totals:

    GU[:netva][YR,R,S,[:sudo]] = GU[:gspcat0][YR,R,S,[:cmp]] + GU[:gsp0][YR,R,S,[:reported]] - GU[:gspcat0][YR,R,S,[:cmp]] - GU[:gspcat0][YR,R,S,[:taxsbd]]
    GU[:netva][YR,R,S,[:comp]] = GU[:gspcat0][YR,R,S,[:cmp]] + GU[:gspcat0][YR,R,S,[:gos]]
    
    # Potential future update might be to define labor component of value added
    # demand using region average for stability purposes. I.e. find labor shares that
    # match US average but allow for distribution in GSP data.
    
    for yr∈YR,r∈R,s∈S
        GU[:labor_shr][[yr],[r],[s]] = GU[:netva][[yr],[r],[s],[:comp]]!=0 ? GU[:gspcat0][[yr],[r],[s],[:cmp]] / GU[:netva][[yr],[r],[s],[:comp]] : 0
    end
    # In cases where the labor share is zero (e.g. banking and finance), use the
    # national average.
    


    for yr∈YR,r∈R,s∈S
        GU[:labor_shr][[yr],[r],[s]] = (GU[:labor_shr][[yr],[r],[s]]==0 && GU[:region_shr][[yr],[r],[s]]>0) ? GU[:lshr_0][[yr],[s]] : GU[:labor_shr][[yr],[r],[s]]
    end



    # How do national averages compare with what national BEA reports? -- remarkably
    # well.


    GU[:comparelshr][YR,S,[:bea]] = GU[:lshr_0][YR,S]

    for yr∈YR,s∈S
        GU[:comparelshr][[yr],[s],[:gsp]] = sum(GU[:netva][[yr],R,[s],[:comp]])!=0 ? sum(GU[:gspcat0][[yr],R,[s],[:cmp]]) / sum(GU[:netva][[yr],R,[s],[:comp]]) : 0
        GU[:seclaborshr][[yr],[s]] = sum(1 for r∈GU[:r] if GU[:labor_shr][[yr],[r],[s]]<1;init=0)!=0 ? (1/sum(1 for r∈R if GU[:labor_shr][[yr],[r],[s]] < 1))* sum(GU[:labor_shr][[yr],[r],[s]] for r∈R if GU[:labor_shr][[yr],[r],[s]] < 1) : GU[:seclaborshr][[yr],[s]]
    end


    for r∈R,s∈S
        GU[:avgwgshr][[r],[s]] = (minimum(GU[:labor_shr][YR,[r],[s]])<=1) ? 1/sum(1 for yr∈YR if GU[:labor_shr][[yr],[r],[s]]<=1) * sum(GU[:labor_shr][[yr],[r],[s]] for yr∈YR if GU[:labor_shr][[yr],[r],[s]]<=1) : GU[:avgwgshr][[r],[s]]
    end



    for r∈R,s∈S

        if minimum([e for e in GU[:labor_shr][:yr,[r],[s]] if e>0];init=Inf)>1
            GU[:labor_shr][:yr,[r],[s]] = GU[:seclaborshr][:yr,[s]]

        elseif GU[:avgwgshr][[r],[s]]!=0
            yr = GU[:labor_shr][:yr,[r],[s]].>1
            GU[:labor_shr][yr,[r],[s]] = (GU[:labor_shr][yr,[r],[s]] .= GU[:avgwgshr][[r],[s]])
        end
    end
    
end