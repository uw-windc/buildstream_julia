using GamsStructure
using CSV


function pceshare(;base_set_dir = "base_data_2017/set", 
                    base_parm_dir = "base_data_2017/parameter",
                    map_path = "maps/mappce.csv",
                    output_path = missing)

    GU = load_pceshare_data(set_dir = base_set_dir,
                            parm_dir = base_parm_dir)

    pce_map = load_pceshare_map(map_file = map_path)

    for g∈GU[:g]
        GU[:pce_map_agr][:yr,:r,[g]] = GU[:pce_units][:yr,:r,[pce_map[g]]]
    end
    
    GU[:pce_shr][:yr,:r,:g] = GU[:pce_map_agr][:yr,:r,:g]./sum(GU[:pce_map_agr][:yr,:r,:g],dims=2)

    if !(ismissing(output_path))
        unload(GU,output_path,to_unload = [:yr,:r,:i,:pce_shr])
    end

    return GU
end



function load_pceshare_data(;set_dir = "base_data_2017/set",parm_dir = "base_data_2017/parameter")


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
        :pg, :pce_units, 3, "Dynamically created set from parameter pce_units, PCE goods"
        :pce_units_domain, :pce_units, 4, "PCE units"
    end)

    @GamsParameters(GU,parm_dir,begin
        :pce_units, (:yr,:sr,:pg,:pce_units_domain), "Personal expenditure data with units as domain", [1,2,3,4]
    end)


    @GamsParameters(GU,begin
        :pce_map_agr, (:yr,:r,:i), "mapped PCE data"
        :pce_shr, (:yr,:r,:i), "Regional shares of final consumption"
    end)

    return GU

end

function load_pceshare_map(;map_file ="maps/mappce.csv" )

    mappce = Dict()
    F = CSV.File(map_file,stringtype=String,
                silencewarnings=true,header = [:a,:b,:c])

    for row in F
        key = Symbol(row[1])
        val = Symbol(string(row[2]))
        mappce[val] = key
        #if key∈keys(mappce)
        #    push!(mappce[key],val)
        #else
        #    mappce[key] = [val]
        #end
        #mappce[Symbol(string(row[2]))] = Symbol(row[1])
    end
    return mappce
end