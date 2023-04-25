using GamsStructure


function PartitionBEA(;input_dir = "data/nationalmodel_raw_data",output_dir = missing)

    GU = load_universe(input_dir)
    alias(GU,:i,:j)


    partitionBEA_extract_from_tables!(GU)

    partitionBEA_adjust_table_data!(GU)

    partitionBEA_extract_parameters!(GU)

    partitionBEA_zero_marginal_goods!(GU)


    
    #potentially more clear with for loops. Could eliminate with masking, probably.

    partitionBEA_create_taxes!(GU)


    if !(ismissing(output_dir))
        unload(GU,output_dir)
    end

    return GU

end


function partitionBEA_extract_from_tables!(GU::GamsUniverse)

    IR_USE_ALL = GU[:ir_use]
    IR_USE = GU[:i][IR_USE_ALL]
    JC_USE_ALL = GU[:jc_use]
    JC_USE = GU[:i][JC_USE_ALL]
    IR_SUPPLY_ALL = GU[:ir_supply]
    IR_SUPPLY = GU[:i][IR_SUPPLY_ALL]
    JC_SUPPLY_ALL = GU[:jc_supply]
    JC_SUPPLY = GU[:j][JC_SUPPLY_ALL]

    FD = GU[:fd][JC_USE_ALL]
    VA = GU[:va][IR_USE_ALL]
    TS = GU[:ts][IR_USE_ALL]

    GU[:id_0][:yr,IR_USE,JC_USE] = GU[:use][:yr,IR_USE,JC_USE];
    GU[:ys_0][:yr,JC_SUPPLY,IR_SUPPLY] = permutedims(GU[:supply][:yr,IR_SUPPLY,JC_SUPPLY],[1,3,2])


    GU[:fd_0][:yr,IR_USE,FD]    = GU[:use][:yr,IR_USE,FD]
    GU[:va_0][:yr,VA,JC_USE]    = GU[:use][:yr,VA,JC_USE]
    GU[:ts_0][:yr,TS,JC_USE]    = GU[:use][:yr,TS,JC_USE]
    GU[:ts_0][:yr,[:subsidies],:j] = -GU[:ts_0][:yr,[:subsidies],:j]

    GU[:m_0][:yr,IR_SUPPLY]    = GU[:supply][:yr,IR_SUPPLY,[:imports]]

    GU[:mrg_0][:yr,IR_SUPPLY]  = GU[:supply][:yr,IR_SUPPLY,[:Margins]]
    GU[:trn_0][:yr,IR_SUPPLY]  = GU[:supply][:yr,IR_SUPPLY,[:TrnCost]]
    GU[:cif0][:yr,IR_SUPPLY]  = GU[:supply][:yr,IR_SUPPLY,[:ciffob]]
    GU[:duty_0][:yr,IR_SUPPLY] = GU[:supply][:yr,IR_SUPPLY,[:Duties]]
    GU[:tax_0][:yr,IR_SUPPLY]  = GU[:supply][:yr,IR_SUPPLY,[:Tax]]
    GU[:sbd_0][:yr,IR_SUPPLY]  = - GU[:supply][:yr,IR_SUPPLY,[:Subsidies]]
    GU[:x_0][:yr,IR_USE]       = GU[:use][:yr,IR_USE,[:exports]]


end


function partitionBEA_adjust_table_data!(GU::GamsUniverse)

    # Treat negative inputs as outputs
    GU[:ys_0][:yr,:j,:i] = GU[:ys_0][:yr,:j,:i] - min.(0,permutedims(GU[:id_0][:yr,:i,:j],[1,3,2]))
    GU[:id_0][:yr,:i,:j]          = max.(0,GU[:id_0][:yr,:i,:j])

    #Adjust transport margins for transport sectors according to CIF/FOB
    #adjustments. Insurance imports are specified as net of adjustments.

    iₘ  = [e for e ∈GU[:i] if e!=:ins]

    GU[:trn_0][:yr,iₘ] = GU[:trn_0][:yr,iₘ] .+ GU[:cif0][:yr,iₘ]
    GU[:m_0][:yr,[:ins]] = GU[:m_0][:yr,[:ins]] .+ GU[:cif0][:yr,[:ins]]
    #GU[:cif0][:yr,i] .= 0

end


function partitionBEA_extract_parameters!(GU::GamsUniverse)

    GU[:y_0][:yr,:i] = sum(GU[:ys_0][:yr,:j,:i],dims = 2)
    
    GU[:s_0][:yr,:j] = sum(GU[:ys_0][:yr,:i,:j],dims = 2)
    GU[:ms_0][:yr,:i,[:trd]] = max.(-GU[:mrg_0][:yr,:i],0)
    GU[:ms_0][:yr,:i,[:trn]] = max.(-GU[:trn_0][:yr,:i],0) 

    GU[:md_0][:yr,[:trd],:i] = max.(GU[:mrg_0][:yr,:i],0)
    GU[:md_0][:yr,[:trn],:i] = max.(GU[:trn_0][:yr,:i],0) 

    GU[:fs_0][:yr,:i] = -min.(0,GU[:fd_0][:yr,:i,[:pce]])

    GU[:y_0][:yr,:i] = permutedims(sum(GU[:ys_0][:yr,:j,:i],dims=2),[1,3,2]) + GU[:fs_0][:yr,:i] - sum(GU[:ms_0][:yr,:i,:m],dims=3) 

    JC_USE_ALL = GU[:jc_use]
    FD = GU[:fd][JC_USE_ALL]

    GU[:a_0][:yr,:i] = sum(GU[:fd_0][:yr,:i,FD],dims=3) + sum(GU[:id_0][:yr,:i,:j],dims=3)


end


function partitionBEA_zero_marginal_goods!(GU::GamsUniverse)

    GU[:y_0][:yr,:imrg]      = 0*GU[:y_0][:yr,:imrg]
    GU[:a_0][:yr,:imrg]      = 0*GU[:a_0][:yr,:imrg]
    GU[:tax_0][:yr,:imrg]    = 0*GU[:tax_0][:yr,:imrg]
    GU[:sbd_0][:yr,:imrg]    = 0*GU[:sbd_0][:yr,:imrg] 
    GU[:x_0][:yr,:imrg]      = 0*GU[:x_0][:yr,:imrg]
    GU[:m_0][:yr,:imrg]      = 0*GU[:m_0][:yr,:imrg]
    GU[:md_0][:yr,:m,:imrg]  = 0*GU[:md_0][:yr,:m,:imrg]
    GU[:duty_0][:yr,:imrg]   = 0*GU[:duty_0][:yr,:imrg]
end


function partitionBEA_create_taxes!(GU::GamsUniverse)

    for yr∈GU[:yr],i∈GU[:i]
        GU[:tm_0][[yr],[i]] = (GU[:duty_0]!=0 && GU[:m_0][[yr],[i]] > 0) ? GU[:duty_0][[yr],[i]]./GU[:m_0][[yr],[i]] : 0
    end

    for yr∈GU[:yr],i∈GU[:i]
        GU[:ta_0][[yr],[i]] = GU[:a_0][[yr],[i]]!=0 ? (GU[:tax_0][[yr],[i]] - GU[:sbd_0][[yr],[i]])./GU[:a_0][[yr],[i]] : 0
    end
end

function partitionBEA_interm(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        use, "use"
        id0, "id0"
        chk, ""
    end)

    @GamsParameters(G,begin
        :interm, (:yr,:j,:tmp), "Total intermediate inputs (purchasers' prices)"
    end)

    YR = G[:yr]
    I = G[:i]
    J = G[:j][G[:jc_use]]
    interm = G[:interm]

    #for yr∈YR,j∈J
    interm[:yr,J,[:use]] = G[:use][:yr,[:interm],J]
    interm[:yr,J,[:id0]] = sum(G[:id_0][:yr,:i,J],dims=2)
    interm[:yr,J,[:chk]] = interm[:yr,J,[:use]] - interm[:yr,J,[:id0]]
    #end

    return interm

end


function partitionBEA_basicva(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        use, ""
        va0, ""
        chk, ""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:j,:tmp), "Basic value added (purchasers' prices)"
    end)

    YR = G[:yr]
    I = G[:i]
    J = G[:j][G[:jc_use]]
    VA = G[:va]
    parm = G[:parm]

    #for yr∈YR,j∈J
    parm[:yr,J,[:use]] = G[:use][:yr,[:basicvalueadded],J]
    parm[:yr,J,[:va0]] = sum(G[:va_0][:yr,:va,J],dims=2)
    parm[:yr,J,[:chk]] = parm[:yr,J,[:use]] - parm[:yr,J,[:va0]]
    #end

    return parm

end


function partitionBEA_valueadded(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        use, ""
        va0_ts0, ""
        chk, ""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:j,:tmp), "Value added (purchaser's prices)"
    end)

    YR = G[:yr]
    I = G[:i]
    J = G[:j][G[:jc_use]]
    VA = G[:va]
    parm = G[:parm]
    ts0 = G[:ts_0]


    #for yr∈YR,j∈J
    parm[:yr,J,[:use]] = G[:use][:yr,[:valueadded],J]
    parm[:yr,J,[:va0_ts0]] = permutedims(sum(G[:va_0][:yr,:va,J],dims=2),[1,3,2]) + ts0[:yr,[:taxes],J] - ts0[:yr,[:subsidies],J]
    parm[:yr,J,[:chk]] = parm[:yr,J,[:use]] - parm[:yr,J,[:va0_ts0]]
    #end

    return parm

end

function partitionBEA_taxtotal(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        ts_subsidies, ""
        ts_taxes, ""
        s0, ""
        t0_duty, ""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:tmp), "Check on total taxes"
    end)

    YR = G[:yr]
    I = G[:i]
    J = G[:j]
    parm = G[:parm]
    ts0 = G[:ts_0]


    #for yr∈YR
    parm[:yr,[:ts_subsidies]] = sum(ts0[:yr,[:subsidies],:j],dims=2)
    parm[:yr,[:ts_taxes]] = sum(ts0[:yr,[:taxes],:j],dims=2)
    parm[:yr,[:s0]] = sum(G[:sbd_0][:yr,:i],dims=2)
    parm[:yr,[:t0_duty]] = sum(G[:tax_0][:yr,:i] .+ G[:duty_0][:yr,:i],dims=2)
    #end

    return parm

end

function partitionBEA_output(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        use, ""
        id0_va0,""
        ys0,""
        chk,""
        chk_ys0,""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:j,:tmp), "Total industry output (basic prices)"
    end)

    YR = G[:yr]
    I = G[:i]
    J = G[:j][G[:jc_use]]
    VA = G[:va]
    parm = G[:parm]
    ts0 = G[:ts_0]


    #for yr∈YR,j∈J
    parm[:yr,J,[:use]] = G[:use][:yr,[:industryoutput],J]
    parm[:yr,J,[:id0_va0]] = sum(G[:va_0][:yr,:va,J],dims=2) + sum(G[:id_0][:yr,:i,J],dims=2)
    parm[:yr,J,[:ys0]] = sum(G[:ys_0][:yr,J,:i],dims=3)
    parm[:yr,J,[:chk]] = parm[:yr,J,[:id0_va0]] - parm[:yr,J,[:use]]
    parm[:yr,J,[:chk_ys0]] = parm[:yr,J,[:id0_va0]] - parm[:yr,J,[:ys0]]
    #end

    return parm

end


function partitionBEA_totint(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        use, ""
        id0,""
        chk,""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:i,:tmp), "Total intermediate use (purchasers' prices)"
    end)

    YR = G[:yr]
    I = G[:i][G[:ir_use]]
    J = G[:j]
    parm = G[:parm]

    #for yr∈YR,i∈I
    parm[:yr,I,[:use]] = G[:use][:yr,I,[:totint]]
    parm[:yr,I,[:id0]] = sum(G[:id_0][:yr,I,:j],dims=3)
    parm[:yr,I,[:chk]] = parm[:yr,I,[:use]] - parm[:yr,I,[:id0]]
    #end

    return parm

end

function partitionBEA_totaluse(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        use, ""
        id0_fd0,""
        chk,""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:i,:tmp), "Total use of commodities (purchasers' prices)"
    end)

    YR = G[:yr]
    I = G[:i][G[:ir_use]]
    J = G[:j]
    FD = G[:fd]
    parm = G[:parm]

    #for yr∈YR,i∈I
    parm[:yr,I,[:use]] = G[:use][:yr,I,[:totaluse]]
    parm[:yr,I,[:id0_fd0]] = sum(G[:id_0][:yr,I,:j],dims=3) + sum(G[:fd_0][:yr,I,:fd],dims=3) + GU[:x_0][:yr,I]
    parm[:yr,I,[:chk]] = parm[:yr,I,[:use]] - parm[:yr,I,[:id0_fd0]]
    #end

    return parm

end

function partitionBEA_basicsupply(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        supply, ""
        ys0, ""
        chk, ""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:i,:tmp), "Basic supply"
    end)

    YR = G[:yr]
    I = G[:i][G[:ir_supply]]
    J = G[:j]
    parm = G[:parm]

    #for yr∈YR,i∈I
    parm[:yr,I,[:supply]] = G[:supply][:yr,I,[:BasicSupply]]
    parm[:yr,I,[:ys0]] = sum(G[:ys_0][:yr,:j,I],dims=2)
    parm[:yr,I,[:chk]] = parm[:yr,I,[:supply]] - parm[:yr,I,[:ys0]]
    #end

    return parm

end

function partitionBEA_tsupply(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        supply, ""
        ys0, ""
        totaluse, ""
        chk,""
        supply_use,""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:i,:tmp), "Total supply"
    end)

    YR = G[:yr]
    I = G[:i][G[:ir_supply]]
    J = G[:j]
    FD = G[:fd]
    parm = G[:parm]

    #for yr∈YR,i∈I
    parm[:yr,I,[:supply]] = G[:supply][:yr,I,[:Supply]]
    parm[:yr,I,[:ys0]] = permutedims(sum(G[:ys_0][:yr,:j,I],dims=2),[1,3,2]) + G[:m_0][:yr,I] + G[:mrg_0][:yr,I] + 
                          G[:trn_0][:yr,I] + G[:duty_0][:yr,I] + G[:tax_0][:yr,I] - G[:sbd_0][:yr,I]
    parm[:yr,I,[:totaluse]] = sum(G[:id_0][:yr,I,:j],dims=3) + sum(G[:fd_0][:yr,I,:fd],dims=3) + G[:x_0][:yr,I]
    parm[:yr,I,[:chk]] = parm[:yr,I,[:supply]] - parm[:yr,I,[:totaluse]]
    parm[:yr,I,[:supply_use]] = parm[:yr,I,[:ys0]] - parm[:yr,I,[:totaluse]]
    #end

    return parm

end

function partitionBEA_details(GU::GamsUniverse)

    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        y0, ""
        m0, ""
        mrg_trn,""
        tax_sbd,""
        id0, ""
        fd0,""
        x0,""
        balance,""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:i,:tmp), "Check on accounting identities"
    end)

    YR = G[:yr]
    I = G[:i][G[:ir_supply]]
    J = G[:j]
    FD = G[:fd]
    parm = G[:parm]

    balance = [:y0,:m0,:mrg_trn,:tax_sbd,:id0,:fd0,:x0]

    #for yr∈YR,i∈I
    parm[:yr,I,[:y0]] = G[:y_0][:yr,I]
    parm[:yr,I,[:m0]] = G[:m_0][:yr,I] + G[:duty_0][:yr,I]
    parm[:yr,I,[:mrg_trn]] = G[:mrg_0][:yr,I] + G[:trn_0][:yr,I]
    parm[:yr,I,[:tax_sbd]] = G[:tax_0][:yr,I] - G[:sbd_0][:yr,I]
    parm[:yr,I,[:id0]] = -sum(G[:id_0][:yr,I,:j],dims=3)
    parm[:yr,I,[:fd0]] = -sum(G[:fd_0][:yr,I,:fd],dims=3)
    parm[:yr,I,[:x0]] = -G[:x_0][:yr,I]
    parm[:yr,I,[:balance]] = sum(parm[:yr,I,balance],dims=3)
    #end

    return parm

end

function partitionBEA_imrginfo(GU::GamsUniverse)

    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        a0, ""
        tax0, ""
        sbd0,""
        y0,""
        x0,""
        m0,""
        duty0,""
        trn, ""
        trd,""
    end)

    @GamsParameters(G,begin
        :parm, (:yr,:tmp,:imrg),"Report of margin producing sectors"
    end)

    YR = G[:yr]
    I = G[:i][G[:ir_supply]]
    J = G[:j]
    FD = G[:fd]
    parm = G[:parm]
    imrg = G[:imrg]


    balance = [:y0,:m0,:mrg_trn,:tax_sbd,:id0,:fd0,:x0]

    #for yr∈YR,i∈I
    parm[:yr,[:a0],imrg] = G[:a_0][:yr,imrg]
    parm[:yr,[:tax0],imrg] = G[:tax_0][:yr,imrg]
    parm[:yr,[:sbd0],imrg] = G[:sbd_0][:yr,imrg]
    parm[:yr,[:y0],imrg] = G[:y_0][:yr,imrg]
    parm[:yr,[:x0],imrg] = G[:x_0][:yr,imrg]
    parm[:yr,[:m0],imrg] = G[:m_0][:yr,imrg]
    parm[:yr,[:duty0],imrg] = G[:duty_0][:yr,imrg]
    parm[:yr,[:trn],imrg] = G[:md_0][:yr,[:trn],imrg]
    parm[:yr,[:trd],imrg] = G[:md_0][:yr,[:trd],imrg]
    #end

    return parm

end