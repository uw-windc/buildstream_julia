using GamsStructure
using CSV


function cfsshare(;base_set_dir = "base_data_2017/set", 
                   base_parm_dir = "base_data_2017/parameter",
                   map_path = "maps/mapcfs.csv",
                   output_path = missing)

    GU = load_cfsshare_data(set_dir = base_set_dir,
    parm_dir = base_parm_dir)

    mapcfs = load_cfsshare_map(map_file = map_path)



    for r∈GU[:r],rr∈GU[:r]
        if r==rr
            GU[:d0_][[r],:n,:sg] = GU[:cfsdata_st_units][[r],[r],:n,:sg,[Symbol("millions of us dollars (USD)")]]
        else
            GU[:mrt0_][[r],[rr],:n,:sg] = GU[:cfsdata_st_units][[r],[rr],:n,:sg,[Symbol("millions of us dollars (USD)")]]
        end
    end

    for g∈keys(mapcfs)
        GU[:d0][:r,[g]] = sum(GU[:d0_][:r,:n,mapcfs[g]], dims=(2,3))
        GU[:mrt0][:r,:r,[g]] = sum(GU[:mrt0_][:r,:r,:n,mapcfs[g]],dims=(3,4))
    end
    
    GU[:xn0][:r,:g] = sum(GU[:mrt0][:r,:r,:g],dims=2)
    GU[:mn0][:r,:g] = sum(GU[:mrt0][:r,:r,:g],dims = 1)
    
    
    ng = sum(permutedims(GU[:d0][:r,:g],(2,1)) + sum(permutedims(GU[:mrt0][:r,:r,:g],(3,1,2)),dims=3),dims=2).==0
    ng = ng[:,1,1]
    
    
    GU[:d0][:r,ng] = (GU[:d0][:r,ng] .= 1/sum(.!ng) * sum(GU[:d0][:r,:g],dims=2))
    GU[:xn0][:r,ng] = (GU[:d0][:r,ng] .= 1/sum(.!ng) * sum(GU[:xn0][:r,:g],dims=2))
    GU[:mn0][:r,ng] = (GU[:d0][:r,ng] .= 1/sum(.!ng) * sum(GU[:mn0][:r,:g],dims=2))
    
    
    mask = (GU[:d0][:r,:g] + GU[:mn0][:r,:g]) .!= 0
    
    GU[:rpc][mask] = GU[:d0][mask]./(GU[:d0][mask] + GU[:mn0][mask])
    
    GU[:rpc][:r,[:uti]] = (GU[:rpc][:r,[:uti]] .= .9)
    

    if !(ismissing(output_path))
        unload(GU,output_path,to_unload = [:r,:i,:rpc])
    end

    return GU

end



function load_cfsshare_map(;map_file ="maps/mapcfs.csv" )

    mappce = Dict()
    F = CSV.File(map_file,stringtype=String,
                silencewarnings=true,header = [:a,:b,:c])

    for row in F
        val = Symbol(row[1])
        key = Symbol(string(row[2]))
        if val ∈ keys(mappce)
            push!(mappce[val],key)
        else
            mappce[val] = [key]
        end
    end
    return mappce
end




function load_cfsshare_data(;set_dir = "base_data_2017/set", parm_dir = "base_data_2017/parameter" )                   

    GU = GamsUniverse()


    @GamsSets(GU,set_dir,begin
        :sr, "Super Regions in WiNDC Database"
        :r, "Regions in WiNDC Database"
        #:yr, "Years in WiNDC Database"
        :i, "BEA Goods and sectors categories"
    end)

    alias(GU,:i,:g)

    @GamsDomainSets(GU,parm_dir,begin
        :n, :cfsdata_st_units,   3, "Dynamically created set from cfs2012 parameter, NAICS codes"
        :sg, :cfsdata_st_units, 4, "Dynamically created set from cfs2012 parameter, SCTG codes"
        :cfs_units_domain, :cfsdata_st_units, 5, "Dynamically created set from cfs2012 parameter, units"
    end)

    @GamsParameters(GU,parm_dir,begin
        :cfsdata_st_units, (:sr,:sr,:n,:sg,:cfs_units_domain), "CFS data for 2012, with units as domain", [1,2,3,4,5]
    end)

    @GamsParameters(GU,begin
        :d0_, (:r,:n,:sg),      "State local supply"
        :mrt0_, (:r,:r,:n,:sg), "Multi-regional trade"
        :d0,    (:r,:g),        "Local supply-demand (CFS)"
        :xn0,   (:r,:g),        "National exports (CFS)"
        :mrt0,  (:r,:r,:g),     "Interstate trade (CFS)"
        :mn0,   (:r,:g),        "National demand (CFS)"
        :ng,    (:g,),          "Sectors not included in the CFS"
        :rpc,   (:r,:i),        "Regional purchase coefficient"
        :x0shr, (:r,:i),        "Export shares supply"
    end)

    return GU

end