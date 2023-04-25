

using JuMP
using Ipopt


function calibrate(GU;output_dir = missing)

    calibrate_prepare!(GU)

    I = [e for e in GU[:i]]
    J = [e for e in GU[:j]]
    M = [e for e in GU[:m]]
    FD = [e for e in GU[:fd]]
    VA = [e for e in GU[:va]]


    for yr in GU[:yr]
        m = calibrate_model(GU,yr,optimizer = Ipopt.Optimizer)
        set_silent(m)

        optimize!(m)

        GU[:ys_0][[yr],J,I] = value.(m[:ys0_][J,I])

        GU[:ty_0][[yr],J]    = GU[:ty0][J]
        GU[:fs_0][[yr],I]    = value.(m[:fs0_][I])
        GU[:ms_0][[yr],I,M]  = value.(m[:ms0_][I,M])
        GU[:y_0][[yr],I]     = value.(m[:y0_][I])
        GU[:id_0][[yr],I,J]  = value.(m[:id0_][I,J])
        GU[:fd_0][[yr],I,FD] = value.(m[:fd0_][I,FD])
        GU[:va_0][[yr],VA,J] = value.(m[:va0_][VA,J])
        GU[:a_0][[yr],I]     = value.(m[:a0_][I])
        GU[:x_0][[yr],I]     = value.(m[:x0_][I])
        GU[:m_0][[yr],I]     = value.(m[:m0_][I])
        GU[:md_0][[yr],M,I]  = value.(m[:md0_][M,I])
        
        GU[:bopdef_0][[yr]] = sum(GU[:m_0][[yr],[i]]-GU[:x_0][[yr],[i]] for i∈I if GU[:a_0][[yr],[i]]!=0)

        for j∈J
            GU[:s_0][[yr],[j]] = sum(GU[:ys_0][[yr],[j],I])
        end
    end

    if !(ismissing(output_dir))
        unload(GU,output_dir,to_unload = [
            :fd,:i,:j,:m,:r,:ts,:va,:yr,

            :y_0,:ys_0,:ty_0,:fs_0,:id_0,:fd_0,:va_0,:ts_0,:m_0,
            :x_0,:mrg_0,:trn_0,:duty_0,:sbd_0,:tax_0,:ms_0,:md_0,
            :s_0,:a_0,:bopdef_0,:ta_0,:tm_0,
        ])
    end


    profit = calibrate_zero_profit(GU)
    @assert all(isapprox.(profit,0)) "National Model calibration isn't satisfying the zero profit condition"

    market = calibrate_market_clearance(GU)
    @assert all(isapprox.(market,0)) "National Model calibration isn't satisfying the market clearance condition"


    return GU

end






function calibrate_prepare!(GU)


    GU[:i][:use].active = false
    GU[:i][:oth].active = false

    GU[:j][:use].active = false
    GU[:j][:oth].active = false


    alias(GU,:fd,:othfd)
    GU[:othfd][:pce].active = false

    @GamsSet(GU,:pce,"PCE category of fd",begin
        pce,""
    end);


    ###################
    ## Parameters ##
    ################
    @GamsParameters(GU,begin
        :ty_values, (:yr,:j), "Output tax values"
    end)



    GU[:ty_values][:yr,:j]  = GU[:va_0][:yr,[:othtax],:j]./sum(GU[:ys_0][:yr,:j,:i],dims = 3)



    @GamsParameters(GU,begin
    :y0,	(:i,),	"Gross output"
    :ty0,	(:j,),	"Output tax rate (OTHTAX)"
    :ty_0,  (:yr,:j), "Output tax rate"
    :ys0,	(:j,:i,),	"Sectoral supply"
    :fs0,	(:i,),	"Household supply"
    :id0,	(:i,:j,),	"Intermediate demand"
    :fd0,	(:i,:fd,),	"Final demand"
    :va0,	(:va,:j,),	"Vaue added"
    :ts0,	(:ts,:i,),	"Taxes and subsidies"
    :m0,	(:i,),	"Imports"
    :x0,	(:i,),	"Exports of goods and services"
    :mrg0,	(:i,),	"Trade margins"
    :trn0,	(:i,),	"Transportation costs"
    :duty0,	(:i,),	"Import duties"
    :sbd0,	(:i,),	"Subsidies on products"
    :tax0,	(:i,),	"Taxes on products"
    :ms0,	(:i,:m,),	"Margin supply"
    :md0,	(:m,:i,),	"Margin demand"
    :s0,	(:i,),	"Aggregate supply"
    :d0,	(:i,),	"Sales in the domestic market"
    :a0,	(:i,),	"Armington supply"
    :ta0,	(:i,),	"Tax net subsidy rate on intermediate demand"
    :tm0,	(:i,),	"Import tariff"
    :bopdef_0, (:yr,), "Balance of payments deficit"
    end);


    #####################
    ## Negative values ##
    #####################


    YR = GU[:yr]
    I = GU[:i]
    J = GU[:j]
    M = GU[:m]

    #for yr∈:yr,i∈I,j∈J
    GU[:id_0][:yr,:i,:j] = GU[:id_0][:yr,:i,:j] .- permutedims(min.(0,GU[:ys_0][:yr,:j,:i]),[1,3,2])
    #end

    GU[:ys_0][:yr,J,:i] = max.(0,GU[:ys_0][:yr,J,:i])
    GU[:id_0][:yr,:i,J] = max.(0,GU[:id_0][:yr,:i,J])
    
    GU[:a_0][:yr,:i] = max.(0, GU[:a_0][:yr,:i])
    GU[:x_0][:yr,:i] = max.(0, GU[:x_0][:yr,:i])
    GU[:y_0][:yr,:i] = max.(0, GU[:y_0][:yr,:i])
    GU[:md_0][:yr,M,:i] = max.(0, GU[:md_0][:yr,M,:i])
    GU[:ms_0][:yr,:i,M] = max.(0, GU[:ms_0][:yr,:i,M])
    GU[:fd_0][:yr,:i,[:pce]] = max.(0, GU[:fd_0][:yr,:i,[:pce]])


    #THis is stupid.
    GU[:duty_0][GU[:m_0].==0] = (GU[:duty_0][GU[:m_0].==0] .=1)
    
    #GU[:duty_0][:yr,:i] = GU[:m_0][:yr,:i]==0 ?  0 : GU[:duty_0][:yr,:i]

    @GamsParameters(GU,begin
        :m_shr, (:i,), "Average shares of imports"
        :va_shr, (:j,:va), "average shares of GDP"
    end)


    GU[:m_shr][:i] = transpose(sum(GU[:m_0][:yr,:i],dims = 1)) ./ sum(GU[:m_0][:yr,:i])

    for yr∈GU[:yr],i∈GU[:i]
        GU[:m_0][[yr],[i]] = GU[:m_0][[yr],[i]]<0 ? GU[:m_shr][[i]]*sum(GU[:m_0][[yr],:]) : GU[:m_0][[yr],[i]] 
    end

    for j∈GU[:j],va∈GU[:va]
        GU[:va_shr][[j],[va]] = sum(GU[:va_0][:yr,[va],[j]]) ./ sum(GU[:va_0][:yr,:va,[j]])
    end

    for yr∈GU[:yr],va∈GU[:va],j∈GU[:j]
        GU[:va_0][[yr],[va],[j]] = GU[:va_0][[yr],[va],[j]]<0 ? GU[:va_shr][[j],[va]]*sum(GU[:va_0][[yr],:,[j]]) : GU[:va_0][[yr],[va],[j]]
    end

    return GU

end



function calibrate_model(GU,year; optimizer = Ipopt.Optimizer)
    I       = [i for i in GU[:i]]
    J       = [j for j in GU[:j]]
    M       = [m_ for m_ in GU[:m]]
    FD      = [fd for fd in GU[:fd]]
    VA      = [va for va in GU[:va]]
    PCE_FD  = [pce for pce in GU[:pce]]
    OTHFD   = [fd for fd in GU[:othfd]]

    ys0 = GU[:ys0]
    id0 = GU[:id0]
    fd0 = GU[:fd0]
    va0 = GU[:va0]
    fs0 = GU[:fs0]
    ms0 = GU[:ms0]
    y0  = GU[:y0]
    id0 = GU[:id0]
    a0  = GU[:a0]
    x0  = GU[:x0]
    m0  = GU[:m0]
    md0 = GU[:md0]
    ty0 = GU[:ty0]
    ta0 = GU[:ta0]
    tm0 = GU[:tm0]


    #for i∈I
    y0[:i]  = GU[:y_0][[year],:i]
    fs0[:i] = GU[:fs_0][[year],:i]
    m0[:i]  = GU[:m_0][[year],:i]
    x0[:i]  = GU[:x_0][[year],:i]
    a0[:i]  = GU[:a_0][[year],:i]
    ta0[:i] = GU[:ta_0][[year],:i]
    tm0[:i] = GU[:tm_0][[year],:i]
    #end

    ys0[J,I] = GU[:ys_0][[year],J,I]
    id0[I,J] = GU[:id_0][[year],I,J]
    va0[VA,J] = GU[:va_0][[year],VA,J]
    fd0[I,FD] = GU[:fd_0][[year],I,FD]
    ms0[I,M] = GU[:ms_0][[year],I,M]
    md0[M,I] = GU[:md_0][[year],M,I]


    for j∈J
        ty0[[j]] = va0[[:othtax],[j]]/sum(ys0[[j],[i]] for i∈I)
        va0[[:othtax],[j]] = 0
    end
    
    lob = 0.01 #Lower bound ratio
    upb = 10 #upper bound ratio
    newnzpenalty = 1e3
    
    m = Model(optimizer)


    @variables(m,begin
    ys0_[j=J,i=I]   >= max(0,lob*ys0[[j],[i]])	#"Calibrated variable ys0."
    ms0_[i=I,m_=M]  >= max(0,lob*ms0[[i],[m_]]) #"Calibrated variable ms0." 
    y0_[i=I]        >= max(0,lob*y0[[i]])		#"Calibrated variable y0."
    id0_[i=I,j=J]   >= max(0,lob*id0[[i],[j]])  #"Calibrated variable id0."
    fd0_[i=I,fd=FD] >= max(0,lob*fd0[[i],[fd]])	#"Calibrated variable fd0."
    a0_[i=I]        >= max(0,lob*a0[[i]])     #"Calibrated variable a0."
    x0_[i=I]        >= max(0,lob*x0[[i]])	    #"Calibrated variable x0."
    m0_[i=I]        >= max(0,lob*m0[[i]])		#"Calibrated variable m0."
    md0_[m_=M,i=I]  >= max(0,lob*md0[[m_],[i]]) #"Calibrated variable md0." 
    va0_[va=VA,j=J] >= max(0,lob*va0[[va],[j]])	#"Calibrated variable va0."
    fs0_[I]         >= 0	                #"Calibrated variable fs0."
    end)

 

    function _set_upb(var,parm,sets...)
        for idx ∈ Iterators.product(sets...)
            ind = [[e] for e in idx]
            if parm[ind...] != 0
                set_upper_bound(var[idx...],abs(upb*parm[ind...]))
            end
        end
    end       

    _set_upb(ys0_,ys0,J,I)
    _set_upb(ms0_,ms0,I,M)
    _set_upb(y0_,y0,I)
    _set_upb(id0_,id0,I,J)
    _set_upb(fd0_,fd0,I,FD)
    _set_upb(a0_,a0,I)
    _set_upb(x0_,x0,I)
    _set_upb(m0_,m0,I)
    _set_upb(md0_,md0,M,I)
    _set_upb(va0_,va0,VA,J)


    function _fix(var,parm,sets...)
        for idx ∈ Iterators.product(sets...)
            ind = [[e] for e in idx]
            if parm[ind...] == 0
                fix(var[idx...],0,force=true)
            end
        end
    end

    _fix(ys0_,ys0,J,I)
    _fix(id0_,id0,I,J)
    _fix(va0_,va0,VA,J)
    
    fix.(fs0_[I],fs0[I],force=true)
    fix.(m0_[I] ,m0[I] ,force=true)
    fix.(x0_[I] ,x0[I] ,force=true)

    IMRG = [i for i∈GU[:imrg]]
    fix.(md0_[M,IMRG] ,0,force=true)
    fix.(y0_[IMRG]    ,0,force=true)
    fix.(m0_[IMRG]    ,0,force=true)
    fix.(x0_[IMRG]    ,0,force=true)
    fix.(a0_[IMRG]    ,0,force=true)
    fix.(id0_[IMRG,J] ,0,force=true)
    fix.(fd0_[IMRG,FD],0,force=true)
    

  

    @expression(m,NEWNZ,
          sum(ys0_[j,i]  for j∈J,i∈I   if ys0[[j],[i]]==0) 
        + sum(fs0_[i]    for i∈I       if fs0[[i]]==0) 
        + sum(ms0_[i,m_] for i∈I,m_∈M  if ms0[[i],[m_]]==0) 
        + sum(y0_[i]     for i∈I       if y0[[i]]==0) 
        + sum(id0_[i,j]  for i∈I,j∈J   if id0[[i],[j]]==0) 
        + sum(fd0_[i,fd] for i∈I,fd∈FD if fd0[[i],[fd]]==0) 
        + sum(va0_[va,j] for va∈VA,j∈J if va0[[va],[j]]==0) 
        + sum(a0_[i]     for i∈I       if a0[[i]]==0) 
        + sum(x0_[i]     for i∈I       if x0[[i]]==0) 
        + sum(m0_[i]     for i∈I       if m0[[i]]==0) 
        + sum(md0_[m_,i] for m_∈M,i∈I  if md0[[m_],[i]]==0)
    )



    @objective(m,Min, 
       sum(abs(ys0[[j],[i]])  * (ys0_[j,i]/ys0[[j],[i]]-1)^2   for i∈I,j∈J       if ys0[[j],[i]]!=0)
     + sum(abs(id0[[i],[j]])  * (id0_[i,j]/id0[[i],[j]]-1)^2   for i∈I,j∈J       if id0[[i],[j]]!=0)
     + sum(abs(fd0[[i],[fd]]) * (fd0_[i,fd]/fd0[[i],[fd]]-1)^2 for i∈I,fd∈PCE_FD if fd0[[i],[fd]]!=0)
     + sum(abs(va0[[va],[j]]) * (va0_[va,j]/va0[[va],[j]]-1)^2 for va∈VA,j∈J     if va0[[va],[j]]!=0)
     
     + sum(abs(fd0[[i],[fd]]) * (fd0_[i,fd]/fd0[[i],[fd]]-1)^2 for i∈I,fd∈OTHFD  if fd0[[i],[fd]]!=0)
     + sum(abs(fs0[[i]])      * (fs0_[i]/fs0[[i]]-1)^2         for i∈I           if fs0[[i]]!=0)
     + sum(abs(ms0[[i],[m_]]) * (ms0_[i,m_]/ms0[[i],[m_]]-1)^2 for i∈I,m_∈M      if ms0[[i],[m_]]!=0)
     + sum(abs(y0[[i]])       * (y0_[i]/y0[[i]]-1)^2           for i∈I           if y0[[i]]!=0)
     + sum(abs(a0[[i]])       * (a0_[i]/a0[[i]]-1)^2           for i∈I           if a0[[i]]!=0)
     + sum(abs(x0[[i]])       * (x0_[i]/x0[[i]]-1)^2           for i∈I           if x0[[i]]!=0)
     + sum(abs(m0[[i]])       * (m0_[i]/m0[[i]]-1)^2           for i∈I           if m0[[i]]!=0)
     + sum(abs(md0[[m_],[i]]) * (md0_[m_,i]/md0[[m_],[i]]-1)^2 for m_∈M,i∈I      if md0[[m_],[i]]!=0)
 
     + newnzpenalty * NEWNZ
     
     )


    @constraints(m,begin
        mkt_py[i=I], 
            sum(ys0_[J,i]) + fs0_[i] == sum(ms0_[i,M]) + y0_[i]
        mkt_pa[i=I],
            a0_[i] == sum(id0_[i,J]) + sum(fd0_[i,FD])
        mkt_pm[m_=M],
            sum(ms0_[I,m_]) == sum(md0_[m_,I])
        prf_y[j=J],
            (1-ty0[[j]])*sum(ys0_[j,I]) == sum(id0_[I,j]) + sum(va0_[VA,j])
        prf_a[i=I],
            a0_[i]*(1-ta0[[i]]) + x0_[i] == y0_[i] + m0_[i]*(1+tm0[[i]]) + sum(md0_[M,i])
    end)


    return m

end



function calibrate_zero_profit(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        Y,""
        A,""
    end)

    @GamsParameters(G,begin
        :profit, (:yr,:j,:tmp), " Zero profit condidtions"
    end)

    YR = G[:yr]
    J = G[:j]
    I = G[:i]
    VA = G[:va]
    M = G[:m]

    parm = G[:profit]



    for yr∈YR,j∈J
        parm[[yr],[j],[:Y]] = G[:s_0][[yr],[j]] !=0 ? round((1-G[:ty_0][[yr],[j]]) * sum(G[:ys_0][[yr],[j],I]) - sum(G[:id_0][[yr],I,[j]]) - sum(G[:va_0][[yr],VA,[j]]),digits = 6) : 0

        parm[[yr],[j],[:A]] = round(G[:a_0][[yr],[j]]*(1-G[:ta_0][[yr],[j]]) + G[:x_0][[yr],[j]] - G[:y_0][[yr],[j]] - G[:m_0][[yr],[j]]*(1+G[:tm_0][[yr],[j]]) - sum(G[:md_0][[yr],M,[j]]), digits = 6)

    end

    return parm

end



function calibrate_market_clearance(GU::GamsUniverse)
    G = deepcopy(GU)

    @GamsSet(G,:tmp,"tmp",begin
        PA,""
        PY,""
    end)

    @GamsParameters(G,begin
        :market, (:yr,:i,:tmp), "Market clearance condition"
    end)

    YR = G[:yr]
    J = G[:j]
    I = G[:i]
    FD = G[:fd]
    M = G[:m]

    parm = G[:market]



    for yr∈YR,i∈I
        parm[[yr],[i],[:PA]] = round( G[:a_0][[yr],[i]] - sum(G[:fd_0][[yr],[i],FD])- sum(G[:id_0][[yr],[i],[j]] for j∈J if G[:s_0][[yr],[j]]!=0),digits = 6)
        parm[[yr],[i],[:PY]] = round( sum(G[:ys_0][[yr],[j],[i]] for j∈J if G[:s_0][[yr],[j]]!=0) + G[:fs_0][[yr],[i]] - G[:y_0][[yr],[i]] - sum(G[:ms_0][[yr],[i],M]),digits=6)
    end

    return parm

end