using GamsStructure


function wrong_entries(GU,gams_GU;convert_dict = missing, atol = 1e-5)
    wrong = Dict()

    key = :y0

    for key in keys(gams_GU.parameters)

        old_parm = gams_GU[key]
        if ismissing(convert_dict)
            parm = GU[key]
        else
            parm = GU[convert_dict[key]]
        end
        sets = [[e for e in gams_GU[s]] for s in old_parm.sets]
        for idx in Iterators.product(sets...)
            ind = [[e] for e in idx]
            if !(isapprox(old_parm[ind...],parm[ind...],atol = atol))
                if key ∈ keys(wrong)
                    push!(wrong[key],ind)
                else
                    wrong[key] = [ind]
                end
            end
        end
    end

    for (key,p) in wrong
        println("$key -> $(length(p))")
    end
    return wrong

end


function verify_key(key,wrong,GU,gams_GU;convert_dict = missing)
    out = ""
    for (key,p) in wrong
        out*="$key\n\n"
        for idx in p
            if ismissing(convert_dict)
                val = GU[key][idx...]
            else
                val = GU[convert_dict[key]][idx...]
            end
    
            out*="$idx -> $(val) | $(gams_GU[key][idx...])\n"
        end
        out*="\n-----------\n"
    end
    print(out)

end

function sum_wrong(GU,gams_GU;convert_dict = missing)

    data = Dict()

    for key in keys(gams_GU.parameters)

        old_parm = gams_GU[key]

        if ismissing(convert_dict)
            parm = GU[key]
        else
            parm = GU[convert_dict[key]]
        end

        sets = [[e for e in gams_GU[s]] for s in old_parm.sets]
        for idx in Iterators.product(sets...)
            ind = [[e] for e in idx]
            old_val = old_parm[ind...]
            new_val = parm[ind...]
            #if !(isapprox(old_val,new_val,atol = 1e-5))
            if key ∈ keys(data)
                push!(data[key],new_val-old_val)
            else
                data[key] = [new_val-old_val]
            end
        end
    end


    out = ""

    for key in keys(data)
        s = sum(abs.(data[key]))
        out *= "$key -> $s\n"
    end

    print(out)

end