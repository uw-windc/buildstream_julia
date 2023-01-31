using GamsStructure


set_directory = "base_data_2017/set"
parm_directory = "base_data_2017/parameter"

GU = GamsUniverse()

@GamsSets(GU,set_directory,begin
        :i,       "BEA Goods and sectors categories"
        :yr,      "Years in dataset", false
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


@GamsSet(GU,:m,"Margins",begin
    trn,"Transport"
    trd,"Trade"
end)

@GamsSet(GU,:imrg,"Goods which only generate margins",begin
    mvt, "Motor vehicle and parts dealers (441)"
    fbt, "Food and beverage stores (445)"
    gmt, "General merchandise stores (452)"
end)
                


################
## Parameters ##
################


@GamsParameters(GU,parm_directory,begin
:use ,     (:yr,:ir_use,:jc_use),       "Annual use matrix with units domain"
:supply ,  (:yr,:ir_supply,:jc_supply), "Annual supply matrix with units domain"
end)

GU[:use][:,:,:] = GU[:use][:,:,:]*1e-3
GU[:supply][:,:,:] = GU[:supply][:,:,:]*1e-3

@GamsParameters(GU, begin
#:use   , (:yr,:ir_use,:jc_use),       "Annual use matrix without units domain"
#:supply, (:yr,:ir_supply,:jc_supply), "Annual supply matrix without usings domain"

:y_0    , (:yr,:i),	    "Gross output"
:ys_0   , (:yr,:j,:i),	"Sectoral supply"
:fs_0   , (:yr,:i),	    "Household supply"
:id_0   , (:yr,:i,:j),	"Intermediate demand"
:fd_0   , (:yr,:i,:fd),	"Final demand,"
:va_0   , (:yr,:va,:j),	"Value added"
:ts_0   , (:yr,:ts,:j),	"Taxes and subsidies"
:m_0    , (:yr,:i),	    "Imports"
:x_0    , (:yr,:i),	    "Exports of goods and services"
:mrg_0  , (:yr,:i),	    "Trade margins"
:trn_0  , (:yr,:i),	    "Transportation costs"
:cif0  , (:yr,:i),	    "CIF/FOB Adjustments on Imports"
:duty_0 , (:yr,:i),	    "Import duties"
:sbd_0  , (:yr,:i),	    "Subsidies on products"
:tax_0  , (:yr,:i),	    "Taxes on products"
:ms_0   , (:yr,:i,:m),   "Margin supply"
:md_0   , (:yr,:m,:i),   "Margin demand"
:s_0    , (:yr,:i),      "Aggegrate Supply"
:d_0    , (:yr,:i),      "Sales in the domestic market"
:a_0    , (:yr,:i),      "Armington supply"
:bopdef, (:yr,),        "Balance of payments deficit"
:tm_0   , (:yr,:i),      "Tax net subsidy rate on intermediate demand"
:ta_0   , (:yr,:i),      "Import tariff"
end
)


unload(GU,"nationalmodel_raw_data")