using MPSGE
using Complementarity
using GamsStructure
using Suppressor
using CSV



function national_model(;solver_output = "nationalmodel.txt",input_dir = "data/nationaldata_ls_julia")

    GU = load_universe(input_dir)

    national_model_prepare!(GU)

    yr = Symbol("2017")  
    models = Dict()

    out = ""

    for yr in GU[:yr]

        out*= "Running year $yr\n\n"

        
        I = GU[:i]
        J = GU[:j]
        FD = GU[:fd]
        M = GU[:m]
        VA = GU[:va]


        GU[:y0][I] = GU[:y_0][[yr],I]
        GU[:ys0][J,I] = GU[:ys_0][[yr],J,I]
        GU[:ty0][J] = GU[:ty_0][[yr],J]
        GU[:fs0][I] = GU[:fs_0][[yr],I]
        GU[:id0][I,J] = GU[:id_0][[yr],I,J]
        GU[:fd0][I,FD] = GU[:fd_0][[yr],I,FD]
        GU[:va0][VA,J] = GU[:va_0][[yr],VA,J]
        GU[:m0][I] = GU[:m_0][[yr],I]
        GU[:x0][I] = GU[:x_0][[yr],I]
        GU[:ms0][I,M] = GU[:ms_0][[yr],I,M]
        GU[:md0][M,I] = GU[:md_0][[yr],M,I]
        GU[:a0][I] = GU[:a_0][[yr],I]

        GU[:ty][J] = GU[:ty0][J]
        
        GU[:bopdef][] = sum(GU[:m0][[i]]-GU[:x0][[i]] for i ∈GU[:i])

        GU[:ta0][I] = GU[:ta_0][[yr],I]
        GU[:tm0][I] = GU[:tm_0][[yr],I]

        GU[:ta][I] = GU[:ta0][I]
        GU[:tm][I] = GU[:tm0][I]

        #m = national_model_mpsge(GU)
        #solve!(m,cumulative_iteration_limit = 0)

        m_bench = national_model_mcp(GU)
        fix(m_bench[:RA], sum(GU[:fd0][[i],[:pce]] for i∈GU[:i]),force = true)

        out*=  "Benchmark\n\n"

        out*= @capture_out solveMCP(m_bench,cumulative_iteration_limit = 0)

        GU[:ta][I] = 0*GU[:ta0][I]
        GU[:tm][I] = 0*GU[:tm0][I]

        m = national_model_mcp(GU)


        out*= "\n\nShock\n\n"
        out*= @capture_out solveMCP(m,cumulative_iteration_limit =10000)

        out*= "\n\n----------------------------------------------\n\n"

        models[yr] = (m_bench,m)

    end

    write(solver_output,out);

    return models

end




function national_model_prepare!(GU)



    GU[:i][:use].active = false
    GU[:i][:oth].active = false
    
    GU[:j][:use].active = false
    GU[:j][:oth].active = false
    
    alias(GU,:i,:y_)
    alias(GU,:i,:a_)
    alias(GU,:i,:py_)
    alias(GU,:fd,:xfd)
    
    
    @create_parameters(GU,begin
    :y0  ,     (:i,),       "Gross output"
    :ys0 ,     (:j, :i),    "Sectoral supply"
    :ty0 ,     (:j,),       "Output tax rate"
    :fs0 ,     (:i,),       "Household supply"
    :id0 ,     (:i, :j),    "Intermediate demand"
    :fd0 ,     (:i, :fd),   "Final demand"
    :va0 ,     (:va, :j),   "Value added"
    :ts0 ,     (:ts, :i),   "Taxes and subsidies"
    :m0 ,      (:i,),       "Imports"
    :x0 ,      (:i,),       "Exports of goods and services"
    :mrg0 ,    (:i,),       "Trade margins"
    :trn0 ,    (:i,),       "Transportation costs"
    :duty0 ,   (:i,),       "Import duties"
    :sbd0 ,    (:i,),       "Subsidies on products"
    :tax0 ,    (:i,),       "Taxes on products"
    :ms0 ,     (:i, :m),    "Margin supply"
    :md0 ,     (:m, :i),    "Margin demand"
    :s0 ,      (:i,),        "Aggregate supply"
    #:d0,      (:i,),	    "Sales in the domestic market"
    :a0 ,      (:i,),       "Armington supply"
    :bopdef , (),         "Balance of payments deficit"
    :ta0 ,     (:i,),       "Tax net subsidy rate on intermediate demand"
    :tm0 ,     (:i,),       "Import tariff"
    
    :ty,       (:j,),	    "Output tax rate"
    :ta,       (:i,),	    "Tax net subsidy rate on intermediate demand"
    :tm,       (:i,),	    "Import tariff"
    
    :thetava , (:va,:j),    "Value-added shares"
    :thetam ,  (:i,),       "Import value share"
    :thetax ,  (:i,),       "Export value share"
    :thetac ,  (:i,),       "Benchmark value shares"
    end)
    
    #@GamsScalars(GU,begin
    #    :bopdef, 0
    #end);
    
    return GU
end




function national_model_mcp(GU)
    m = MCPModel()

    ###################
    ### GU ##########
    ###################

    VA = GU[:va]
    J = GU[:j]
    I = GU[:i]
    M = GU[:m]


    #Y_ = GU[:y_]
    #A_ = GU[:a_]
    #XFD = GU[:xfd]
    Y_ = [j for j in GU[:y_] if sum(GU[:ys0][[j],[i]] for i∈I)!=0]
    A_ = [i for i in GU[:a_] if GU[:a0]!=0]
    PY_ = [i for i in GU[:py_] if sum(GU[:ys0][[j],[i]] for j∈J)!=0]
    XFD = [fd for fd in GU[:xfd] if fd!=:pce]


    ####################
    ## Parameters ######
    ####################

    va0 = GU[:va0]
    m0 = GU[:m0]
    tm0 = GU[:tm0]
    y0 = GU[:y0]
    a0 = GU[:a0]
    ta0 = GU[:ta0]
    x0 = GU[:x0]
    fd0 = GU[:fd0]

    thetava = GU[:thetava]
    thetam = GU[:thetam]
    thetax = GU[:thetax]
    thetac = GU[:thetac]

    thetava[:va,:j] = 0*GU[:thetava][:va,:j]
    thetam[:i] = 0*GU[:thetam][:i]
    thetax[:i] = 0*GU[:thetax][:i]
    thetac[:i] = 0*GU[:thetac][:i]

    ty = GU[:ty]
    ms0 = GU[:ms0]
    bopdef = GU[:bopdef][]
    fs0 = GU[:fs0]
    ys0 = GU[:ys0]
    id0 = GU[:id0]
    md0 = GU[:md0]

    tm = GU[:tm]
    ta = GU[:ta]



    for va∈VA, j∈J
        if va0[[va],[j]]≠0
            thetava[[va],[j]] = va0[[va],[j]]/sum(va0[[v],[j]] for v∈VA)
        end
    end
    

    mask = m0.value .!=0
    thetam[mask] = m0[mask].*(1 .+tm0[mask])./(m0[mask].*(1 .+tm0[mask] ).+ y0[mask])
    
    mask = x0.value .!=0
    thetax[mask] = x0[mask]./(x0[mask].+a0[mask].*(1 .-ta0[mask]))

    thetac[:i] = fd0[:i,[:pce]]./sum(fd0[:i,[:pce]])
    
    #for i∈I
    #    if m0[[i]]≠0
    #        thetam[[i]] = m0[[i]]*(1+tm0[[i]])/(m0[[i]]*(1+tm0[[i]]) + y0[[i]])
    #    end
    #    if x0[[i]]≠0
    #        thetax[[i]] = x0[[i]]/(x0[[i]]+a0[[i]]*(1-ta0[[i]]))
    #    end
    #    thetac[[i]] = fd0[[i],[:pce]]/sum(fd0[[ii],[:pce]] for ii∈ I)
    #end
    

    @variables(m,begin
        Y[J]>=0,    (start = 1,)
        A[I]>=0,    (start = 1,)
        MS[M]>=0,   (start = 1,)
        PA[I]>=0,   (start = 1,)
        PY[I]>=0,   (start = 1,)
        PVA[VA]>=0, (start = 1,)
        PM[M]>=0,   (start = 1,)
        PFX>=0,     (start = 1,)
        RA>=0,      (start = 1000,)
    end)

    ####################
    ## Macros in Gams ##
    ####################
    @mapping(m, CVA[j=J],
        prod(PVA[va]^thetava[[va],[j]] for va∈VA)
    )

    @mapping(m, PMD[i=I],
        (thetam[[i]]*(PFX*(1+tm[[i]])/(1+tm0[[i]]))^(1-2) + (1-thetam[[i]])*PY[i]^(1-2))^(1/(1-2))
    )

    @mapping(m, PXD[i=I],
        (thetax[[i]]*PFX^(1+2) + (1-thetax[[i]])*(PA[i]*(1-ta[[i]])/(1-ta0[[i]]))^(1+2))^(1/(1+2))
    )

    @mapping(m, MD[i=I],
        A[i]*m0[[i]]*( (PMD[i]*(1+tm0[[i]])) / (PFX*(1+tm[[i]])))^2
    )

    @mapping(m, YD[i=I],
        A[i]*y0[[i]]*(PMD[i]/PY[i])^2
    )

    @mapping(m, XS[i=I],
        A[i]*x0[[i]]*(PFX/PXD[i])^2
    )

    @mapping(m, DS[i = I],
        A[i]*a0[[i]]*(PA[i]*(1-ta[[i]])/(PXD[i]*(1-ta0[[i]])))^2
    )

    ########################
    ## End of GAMS Macros ##
    ########################

    #defined on y_(j)
    @mapping(m,prf_Y[j=Y_],
       CVA[j]*sum(va0[[va],[j]] for va∈VA) +sum(PA[i]*id0[[i],[j]] for i∈I) - sum(PY[i]*ys0[[j],[i]] for i∈I)*(1-ty[[j]])
    )


    
    #defined on a_(i)
    @mapping(m,prf_A[i = A_],
        sum(PM[m_]*md0[[m_],[i]] for m_∈M) + 
        PMD[i] * 
        (y0[[i]] +(1+tm0[[i]])*m0[[i]]) -
        PXD[i] *
        (x0[[i]] + a0[[i]]*(1-ta0[[i]]))
    )


    @mapping(m,prf_MS[m_ = M],
        sum(PY[i]*ms0[[i],[m_]] for i∈I) - 
        PM[m_]*sum(ms0[[i],[m_]] for i∈I)
    )


    @mapping(m,bal_RA,
        -RA + sum(PY[i]*GU[:fs0][[i]] for i∈I) + PFX*bopdef
        - sum(PA[i]*fd0[[i],[xfd]] for i∈I,xfd∈XFD) + sum(PVA[va]*va0[[va],[j]] for va∈VA,j∈J)
        + sum(A[i]*(a0[[i]]*PA[i]*ta[[i]] + PFX*MD[i]*tm[[i]]) for i∈I)
        + sum(Y[j]*sum(ys0[[j],[i]]*PY[i] for i∈I)*ty[[j]] for j∈J)
    )

    @mapping(m, mkt_PA[i = A_],
        -DS[i] + thetac[[i]] * RA/PA[i] + sum(fd0[[i],[xfd]] for xfd∈XFD)
        + sum(Y[j]*id0[[i],[j]] for j∈Y_)
    )

    @mapping(m, mkt_PY[i=I],
        -sum(Y[j]*ys0[[j],[i]] for j∈Y_)
        + sum(MS[m_]*ms0[[i],[m_]] for m_∈M) + YD[i]
    )


    @mapping(m, mkt_PVA[va = VA],
        -sum(va0[[va],[j]] for j∈J)
        + sum(Y[j]*va0[[va],[j]]*CVA[j]/PVA[va] for j∈Y_)
    )

    @mapping(m, mkt_PM[m_ = M],
        MS[m_]*sum(ms0[[i],[m_]] for i∈I)
        - sum(A[i]*md0[[m_],[i]] for i∈I if a0[[i]]≠0)
    )

    @mapping(m, mkt_PFX,
        sum(XS[i] for i∈A_) + bopdef
        - sum(MD[i] for i∈A_)
    )


    @complementarity(m, prf_Y, Y)
    @complementarity(m, prf_A, A)
    @complementarity(m, prf_MS, MS)
    @complementarity(m, bal_RA, RA)
    @complementarity(m, mkt_PA, PA)
    @complementarity(m, mkt_PY, PY)
    @complementarity(m, mkt_PVA, PVA)
    @complementarity(m, mkt_PM, PM)
    @complementarity(m, mkt_PFX, PFX)


    return m
end





function national_model_mpsge(GU)

    m = MPSGE.Model()

    ctrl = Dict()
    @create_parameters(GU,begin
        :y_ , (:j,),    "Sectors with positive production"
        :a_ , (:i,),    "Sectors with absorption"
        :py_ , (:i,),   "Goods with positive supply"
        :xfd , (:fd,),  "Exogenous components of final demand"
    end)


    for j ∈ GU[:j]
        ctrl[:y_][j] = sum(GU[:ys0][j,i] for i ∈ GU[:i])
    end


    for i ∈ GU[:i]
        ctrl[:a_][i] = GU[:a0][i]
        ctrl[:py_][i] = sum(GU[:ys0][j,i] for j ∈ GU[:j])
    end


    for fd ∈ GU[:fd]
        ctrl[:xfd][fd] = fd == :pce ? 1 : 0
    end

    #@sector(m,Y[GU[:j]])

    y_ind = [j for j ∈ GU[:j] if ctrl[:y_][j]!=0]
    a_ind = [i for i ∈ GU[:i] if ctrl[:a_][i]!=0]

    a0_ind = [i for i ∈ GU[:i] if GU[:a0][i]!=0]
    py_ind = [i for i ∈ GU[:i] if ctrl[:py_][i]!=0]

    
    @sector(m,Y,indices = (y_ind,)) #71
    @sector(m,A,indices = (a_ind,)) #71
    @sector(m,MS,indices = ([e for e in GU[:m]],)) #Error here. Accessing elements as arrays. #2


    @commodity(m,PA,indices = (a0_ind,)) #71
    @commodity(m,PY,indices = (py_ind,)) #71
    @commodity(m,PVA,indices = ([e for e in GU[:va]],)) ##
    @commodity(m,PM,indices = ([e for e in GU[:m]],)) ##
    @commodity(m,PFX)

    @consumer(m,RA);

    
    
    for j ∈ y_ind
        @production(m,Y[j],0,1,
            [Output(PY[i],GU[:ys0][j,i]) for i in py_ind], #,RA,GU[:ty][j]
            [
                [Input(PA[i],GU[:id0][i,j]) for i in a0_ind];
                [Input(PVA[va],GU[:va0][va,j]) for va in GU[:va]]
            ]
        )
    end
    

    for m_ ∈ GU[:m]
        @production(m,MS[m_],0,0, #these values are not in GAMS
            [Output(PM[m_],sum(GU[:ms0][i,m_] for i ∈ GU[:i]))],
            [Input(PY[i],GU[:ms0][i,m_]) for i ∈ py_ind]    
        )
    end
   
    
    for i ∈ a_ind
        @production(m,A[i],0,2, #Need to explore these two values
            [
                Output(PA[i],GU[:a0][i]),
                Output(PFX,GU[:x0][i])
            ],
            [
                [Input(PY[i],GU[:y0][i])];
                [Input(PFX,GU[:m0][i])];
                [Input(PM[m],GU[:md0][m,i]) for m ∈ GU[:m]]
            ]
        )
    end

    

    @demand(m,RA,1., #This 1 needs to be a float. That seems... annoying
        [Demand(PA[i],GU[:fd0][i,:pce]) for i ∈ a0_ind],
        [ 
            [Endowment(PY[i],GU[:fs0][i]) for i ∈ py_ind];
            [Endowment(PFX,GU[:bopdef][])];
            [Endowment(PA[i] ,-sum(GU[:fd0][i,xfd] for xfd ∈ GU[:fd])) for i∈a0_ind]; #should be xfd, not fd
            [Endowment(PVA[va],sum(GU[:va0][va,j ] for j  ∈ GU[:j] )) for va∈GU[:va]]
        ]
    );

    return m
end