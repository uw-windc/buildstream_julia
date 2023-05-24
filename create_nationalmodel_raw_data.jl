using GamsStructure

"""
    create_national_raw_data(year,write=true)

Load sets and parameters :use and :supply from base_data_\$year
and write to data_\$year.


"""
function create_national_raw_data(year,write=true)

#year = 2017

    set_directory = "base_data_$year/set"
    parm_directory = "base_data_$year/parameter"

    GU = GamsUniverse()

    @load_sets!(GU,set_directory,begin
    :i,       "BEA Goods and sectors categories"
    :yr,      "Years in dataset"
    :va,      "BEA Value added categories"
    :fd,      "BEA Final demand categories"
    :ts,      "BEA Taxes and subsidies categories"
    end)

    alias(GU,:i,:j) 

    @GamsDomainSets(GU,parm_directory,begin
            :ir_use ,    :use,    2,    "Domain of second column of use_units"
            :ir_supply , :supply, 2,    "Domain of second column of supply_units"
            :jc_use ,    :use,    3,    "Domain of third column of use_units"
            :jc_supply , :supply, 3,    "Domain of third column of supply_units"
    end)

    @create_set!(GU,:m,"Margins",begin
        trn,"Transport"
        trd,"Trade"
    end)

    @create_set!(GU,:imrg,"Goods which only generate margins",begin
        mvt, "Motor vehicle and parts dealers (441)"
        fbt, "Food and beverage stores (445)"
        gmt, "General merchandise stores (452)"
    end)
            
    @load_parameters!(GU,parm_directory,begin
        :use ,     (:yr,:ir_use,:jc_use),       description => "Annual use matrix with units domain"
        :supply ,  (:yr,:ir_supply,:jc_supply), description =>"Annual supply matrix with units domain"
    end)

    GU[:use][:yr,:ir_use,:jc_use] = GU[:use][:yr,:ir_use,:jc_use]*1e-3
    GU[:supply][:yr,:ir_supply,:jc_supply] = GU[:supply][:yr,:ir_supply,:jc_supply]*1e-3;



    #Use
    @create_parameters(GU,begin
        :id_0   , (:yr,:i,:j),	"Intermediate demand"
        :fd_0   , (:yr,:i,:fd),	"Final demand,"
        :va_0   , (:yr,:va,:j),	"Value added"
        :x_0    , (:yr,:i),	    "Exports of goods and services"
        :ts_0   , (:yr,:ts,:j),	"Taxes and subsidies"
        :othtax , (:yr,:j),     "Other taxes - Experimental"
    end)

    #supply
    @create_parameters(GU,begin
        :ys_0   , (:yr,:j,:i),	"Sectoral supply"
        :m_0    , (:yr,:i),	    "Imports"
        :mrg_0  , (:yr,:i),	    "Trade margins"
        :trn_0  , (:yr,:i),	    "Transportation costs"
        :cif0  , (:yr,:i),	    "CIF/FOB Adjustments on Imports"
        :duty_0 , (:yr,:i),	    "Import duties"
        :sbd_0  , (:yr,:i),	    "Subsidies on products"
        :tax_0  , (:yr,:i),	    "Taxes on products"
    end)

    #Partition BEA
    @create_parameters(GU, begin
        :y_0    , (:yr,:i),	    "Gross output"
        :fs_0   , (:yr,:i),	    "Household supply"
        :ms_0   , (:yr,:i,:m),   "Margin supply"
        :md_0   , (:yr,:m,:i),   "Margin demand"
        :s_0    , (:yr,:i),      "Aggegrate Supply"
        :a_0    , (:yr,:i),      "Armington supply"
        :bopdef, (:yr,),        "Balance of payments deficit"
        :tm_0   , (:yr,:i),      "Tax net subsidy rate on intermediate demand"
        :ta_0   , (:yr,:i),      "Import tariff"
        :ty_values, (:yr,:j), "Output tax values"
    end)



    if write
        unload(GU,"data_$year/nationalmodel_raw_data")
    end

    return GU
end