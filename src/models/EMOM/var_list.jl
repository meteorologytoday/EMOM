function getCompleteVariableList(
    mb      :: ModelBlock,
    vartype :: Symbol,
)

    d = nothing

    if vartype == :dynamic
        d = Dict(

            "TEMP"               => ( mb.fi.sv[:TEMP], :T ),
            "SALT"               => ( mb.fi.sv[:SALT], :T ),
            "UVEL"               => ( mb.fi.sv[:UVEL], :U ),
            "VVEL"               => ( mb.fi.sv[:VVEL], :V ),
            "WVEL"               => ( mb.fi.sv[:WVEL], :W ),
            "TAUX"               => ( mb.fi.TAUX,        :sT ),
            "TAUY"               => ( mb.fi.TAUY,        :sT ),
            "TAUX_east"          => ( mb.fi.TAUX_east,   :sT ),
            "TAUY_north"         => ( mb.fi.TAUY_north,  :sT ),
            "SWFLX"              => ( mb.fi.SWFLX,       :sT ),
            "NSWFLX"             => ( mb.fi.NSWFLX,      :sT ),
            "VSFLX"              => ( mb.fi.NSWFLX,      :sT ),
            "ADVT"               => ( mb.fi.sv[:ADVT],     :T ),
            "ADVS"               => ( mb.fi.sv[:ADVS],     :T ),
            "HMXL"               => ( mb.fi.HMXL,          :sT ),
            
            "WKRSTT"       => ( mb.fi.sv[:WKRSTT], :T),
            "WKRSTS"       => ( mb.fi.sv[:WKRSTS], :T),
 
            "VDIFFT"       => ( mb.fi.sv[:VDIFFT], :T),
            "VDIFFS"       => ( mb.fi.sv[:VDIFFS], :T),
            
            "Q_FRZMLTPOT"        => ( mb.fi.Q_FRZMLTPOT,  :sT ),
            "CHKTEMP"            => ( mb.tmpfi.sv[:CHKTEMP],  :sT ),
            "CHKSALT"            => ( mb.tmpfi.sv[:CHKSALT],  :sT ),

            "INTMTEMP"           => ( mb.tmpfi.sv[:INTMTEMP], :T),
            "INTMSALT"           => ( mb.tmpfi.sv[:INTMSALT], :T),

            "WKRST_TARGET_TEMP"         => nothing,
            "WKRST_TARGET_SALT"         => nothing,
            "QFLX_TEMP"          => nothing,
            "QFLX_SALT"          => nothing,
 
        )
        
        if mb.tmpfi.datastream != nothing 

            if mb.ev.config[:weak_restoring] == :on
                d["WKRST_TARGET_TEMP"] = ( mb.tmpfi.datastream["TEMP"], :T )
                d["WKRST_TARGET_SALT"] = ( mb.tmpfi.datastream["SALT"], :T )
            end

            if mb.ev.config[:Qflx] == :on
                d["QFLX_TEMP"] = ( mb.tmpfi.datastream["QFLX_TEMP"], :T )
                d["QFLX_SALT"] = ( mb.tmpfi.datastream["QFLX_SALT"], :T )
            end

        end

    elseif vartype == :static

        #=
        d = Dict(
            # COORDINATEi
            "area"               => ( ocn.mi.area,                  ("Nx", "Ny") ),
            "mask"               => ( ocn.mi.mask,                  ("Nx", "Ny") ),
            "frac"               => ( ocn.mi.frac,                  ("Nx", "Ny") ),
            "c_lon"              => ( ocn.mi.xc,                    ("Nx", "Ny") ),
            "c_lat"              => ( ocn.mi.yc,                    ("Nx", "Ny") ),
            "zs_bone"            => ( ocn.zs_bone,                  ("NP_zs_bone",) ),
        )
        =#

        d = Dict()
    else
        throw(ErrorException("Unknown vartype: " * string(vartype)))
    end

    return d
end

function getVarDesc(varname)
    return haskey(HOOM.var_desc, varname) ? HOOM.var_desc[varname] : Dict()
end

function getDynamicVariableList(
    mb :: ModelBlock;
    varnames :: AbstractArray{String} = Array{String}(undef,0),
    varsets  :: AbstractArray{Symbol} = Array{Symbol}(undef,0),
)

    all_varlist = getCompleteVariableList(mb, :dynamic)
    
    output_varnames = []

    for varname in varnames
        if haskey(all_varlist, varname)
            push!(output_varnames, varname)
        else
            throw(ErrorException(format("Varname {:s} does not exist.", varname)))
        end
    end

    for varset in varsets

        if varset == :ALL

            append!(output_varnames, keys(all_varlist))

        elseif varset == :ESSENTIAL
            
            append!(output_varnames, [

                "TEMP",
                "SALT",
                "UVEL",
                "VVEL",
                "WVEL",
                "TAUX",
                "TAUY",
                "TAUX_east",
                "TAUY_north",
                "SWFLX",
                "NSWFLX",
                "VSFLX",
                "ADVT",
                "ADVS",
                "HMXL",
                
                "WKRSTT",
                "WKRSTS",
     
                "VDIFFT",
                "VDIFFS",
                
                "Q_FRZMLTPOT",
                "CHKTEMP",
                "CHKSALT",

            ])

        else

            throw(ErrorException("Unknown varset: " * string(varset)))

        end
    end


    function makeSubset(dict, keys)
        subset_dict = Dict()
        for k in keys
            if dict[k] != nothing
                subset_dict[k] = dict[k]
            end
        end
        return subset_dict
    end


    output_varlist = makeSubset(all_varlist, output_varnames)

    return output_varlist
end



