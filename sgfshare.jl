using GamsStructure
using CSV



function sgfshare(;base_set_dir = "base_data_2017/set", 
    base_parm_dir = "base_data_2017/parameter",
    map_path = "maps/mapsgf.csv",
    output_path = missing)

    GU = load_sgfshare_data(set_dir = base_set_dir,
                            parm_dir = base_parm_dir
    )

    mapsgf = load_sgfshare_map(map_file = map_path);

    # Note that many of the sectors in WiNDC are mapped to the same SGF
    # category. Thus, sectors will have equivalent shares.

    for g∈GU[:g]
        GU[:sgf_map_agr][:yr,:r,[g]] = sum(GU[:sgf_units][:yr,:r,mapsgf[g],:sgf_raw_units],dims = 3)
    end

    # DC is not represented in the SGF database. Assume similar expenditures as
    # Maryland.
    GU[:sgf_map_agr][:yr,[:DC],:g] = GU[:sgf_map_agr][:yr,[:MD],:g];

    GU[:sgf_shr][:yr,:r,:g] = GU[:sgf_map_agr][:yr,:r,:g]./sum(GU[:sgf_map_agr][:yr,:r,:g],dims=2)


    #for yr∈GU[:yr], g∈GU[:g]
    #    GU[:sgf_shr][[yr],:r,[g]] = sum(GU[:sgf_shr][[yr],:r,[g]])==0 ? GU[:sgf_shr][[yr],:r,[:fdd]] : GU[:sgf_shr][[yr],:r,[g]]
    #end

    GU[:sgf_shr][:yr,:r,:g] = (GU[:sgf_shr][:yr,:r,:g] .= 
                            ifelse.( sum(GU[:sgf_shr][:yr,:r,:g],dims=2).==0,
                                        GU[:sgf_shr][:yr,:r,[:fdd]],
                                        GU[:sgf_shr][:yr,:r,:g])
    )


    if !(ismissing(output_path))
        unload(GU,"data/shares_sgf",to_unload = [:yr,:r,:i,:sgf_shr])
    end

    return GU


end



function load_sgfshare_data(;set_dir = "base_data_2017/set", 
                            parm_dir = "base_data_2017/parameter")
    GU = GamsUniverse()


    @GamsSets(GU,set_dir,begin
        :sr, "Super Regions in WiNDC Database"
        :r, "Regions in WiNDC Database"
        #:pg, "Dynamically created set from parameter pce_units, PCE goods"
        :yr, "Years in WiNDC Database"
        :i, "BEA Goods and sectors categories"
    end)

    alias(GU,:i,:g)

    @GamsDomainSets(GU,parm_dir,begin
        :ec, :sgf_units, 3, "Dynamically created set from the sgf_raw parameter, government expenditure categories";
        :sgf_raw_units, :sgf_units, 4, "Dynamical created set from sgf_raw"
    end)

    @GamsParameters(GU,parm_dir,begin
        :sgf_units, (:yr,:sr,:ec,:sgf_raw_units), "Personal expenditure data, with units as domain", [1,2,3,4]
    end)

    @GamsParameters(GU,begin
        :sgf_map_agr, (:yr,:r,:i), "Mapped PCE data"
        :sgf_shr, (:yr,:r,:i), "Regional shares of final consumption"
    end)

    GU
end


function load_sgfshare_map(;map_file ="maps/mapsgf.csv" )

    mappce = Dict()
    F = CSV.File(map_file,stringtype=String,
                silencewarnings=true,header = [:a,:b,:c])

    for row in F
        key = Symbol(row[1])
        val = Symbol(string(row[2]))
        if val ∈ keys(mappce)
            push!(mappce[val],key)
        else
            mappce[val] = [key]
        end
    end
    return mappce
end

