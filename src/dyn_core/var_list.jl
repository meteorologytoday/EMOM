function getCompleteVariableList(
    mb      :: ModelBlock,
    vartype :: Symbol,
)

    d = nothing

    if vartype == :dynamic
        d = OrderedDict(

            "TEMP"               => ( mb.fi.sv[:TEMP], :T, :mask ),
            "SALT"               => ( mb.fi.sv[:SALT], :T, :mask ),
            "UVEL"               => ( mb.fi.sv[:UVEL], :U, nothing ),
            "VVEL"               => ( mb.fi.sv[:VVEL], :V, nothing ),
            "WVEL"               => ( mb.fi.sv[:WVEL], :W, nothing ),
            "TAUX"               => ( mb.fi.TAUX,        :sT, :mask ),
            "TAUY"               => ( mb.fi.TAUY,        :sT, :mask ),
            "TAUX_east"          => ( mb.fi.TAUX_east,   :sT, :mask ),
            "TAUY_north"         => ( mb.fi.TAUY_north,  :sT, :mask ),
            "SWFLX"              => ( mb.fi.SWFLX,       :sT, :mask ),
            "NSWFLX"             => ( mb.fi.NSWFLX,      :sT, :mask ),
            "VSFLX"              => ( mb.fi.VSFLX,       :sT, :mask ),
            "LWUP"               => ( mb.fi.LWUP,        :sT, :mask ),
            "LWDN"               => ( mb.fi.LWDN,        :sT, :mask ),
            "SEN"                => ( mb.fi.SEN,         :sT, :mask ),
            "LAT"                => ( mb.fi.LAT,         :sT, :mask ),
            "MELTH"              => ( mb.fi.MELTH,       :sT, :mask ),
            "MELTW"              => ( mb.fi.MELTW,       :sT, :mask ),
            "SNOW"               => ( mb.fi.SNOW,        :sT, :mask ),
            "IOFF"               => ( mb.fi.IOFF,        :sT, :mask ),
            "ROFF"               => ( mb.fi.ROFF,        :sT, :mask ),
            "EVAP"               => ( mb.fi.EVAP,        :sT, :mask ),
            "PREC"               => ( mb.fi.PREC,        :sT, :mask ),
            "SALTFLX"            => ( mb.fi.SALTFLX,     :sT, :mask ),
            "ADVT"               => ( mb.fi.sv[:ADVT],    :T, :mask ),
            "ADVS"               => ( mb.fi.sv[:ADVS],    :T, :mask ),
            "HMXL"               => ( mb.fi.HMXL,        :sT, :mask ),
            "USFC"               => ( mb.fi.USFC,        :sT, :mask ),
            "VSFC"               => ( mb.fi.VSFC,        :sT, :mask ),
            
            "WKRSTT"             => ( mb.fi.sv[:WKRSTT], :T, :mask),
            "WKRSTS"             => ( mb.fi.sv[:WKRSTS], :T, :mask),
 
            "VDIFFT"             => ( mb.fi.sv[:VDIFFT], :T, :mask),
            "VDIFFS"             => ( mb.fi.sv[:VDIFFS], :T, :mask),
            
            "Q_FRZMLTPOT"        => ( mb.fi.Q_FRZMLTPOT,  :sT, :mask ),
            "Q_FRZMLTPOT_NEG"    => ( mb.fi.Q_FRZMLTPOT_NEG, :sT, :mask ),
            "Q_FRZHEAT"          => ( mb.fi.Q_FRZHEAT,    :sT, :mask ),
            "Q_FRZHEAT_OVERFLOW"     => ( mb.fi.Q_FRZHEAT_OVERFLOW,       :sT, :mask ),
            "CHKTEMP"            => ( mb.tmpfi.sv[:CHKTEMP],  :sT, :mask ),
            "CHKSALT"            => ( mb.tmpfi.sv[:CHKSALT],  :sT, :mask ),

            "INTMTEMP"           => ( mb.tmpfi.sv[:INTMTEMP], :T, :mask),
            "INTMSALT"           => ( mb.tmpfi.sv[:INTMSALT], :T, :mask),

            "WKRST_TARGET_TEMP"  => nothing,
            "WKRST_TARGET_SALT"  => nothing,
            "QFLXT"              => nothing,
            "QFLXS"              => nothing,
 
            "Ks_H_U"    => ( mb.tmpfi.check_usage[:Ks_H_U], :U, nothing),
            "Ks_H_V"    => ( mb.tmpfi.check_usage[:Ks_H_V], :V, nothing),

        )
        
        if mb.tmpfi.datastream != nothing 

            if mb.ev.cfgs["MODEL_CORE"]["weak_restoring"] == "on"
                d["WKRST_TARGET_TEMP"] = ( mb.tmpfi.datastream["TEMP"]["TEMP"], :T , :mask)
                d["WKRST_TARGET_SALT"] = ( mb.tmpfi.datastream["SALT"]["SALT"], :T , :mask)
            end

        end
        
        d["QFLXT"] = ( mb.fi.sv[:QFLXT], :T, :mask )
        d["QFLXS"] = ( mb.fi.sv[:QFLXS], :T, :mask )

    elseif vartype == :static

        area = view(mb.ev.gf.area, :, mb.ev.sub_yrng)
        area_sT = reshape( area, 1, size(area)... )

        d = Dict(
            # COORDINATE
            "deepmask_T"=> ( mb.ev.topo.deepmask_T, :T, nothing),
            "topoz_sT"  => ( mb.ev.topo.topoz_sT, :sT, nothing),
            "Nz_bot_sT" => ( mb.ev.topo.Nz_bot_sT, :sT, nothing),
            "area_sT"   => ( area_sT, :sT, nothing),
            "mask_sT"   => ( mb.ev.topo.sfcmask_sT, :sT, nothing),
            "z_cW"      => ( reshape(mb.ev.z_w, :, 1, 1), :cW, nothing),
            "dz_cT"     => ( mb.ev.gd.Δz_T[:, 1:1, 1:1], :cT, nothing),
            "lon_sT"    => ( rad2deg.(mb.ev.gd_slab.λ_T), :sT, nothing),
            "lat_sT"    => ( rad2deg.(mb.ev.gd_slab.ϕ_T), :sT, nothing),
        )

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
    varsets  :: AbstractArray{String} = Array{String}(undef,0),
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

        if varset == "ALL"

            append!(output_varnames, keys(all_varlist))

        elseif varset == "ESSENTIAL"
            
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
                "LWUP",
                "LWDN",
                "SEN",
                "LAT",
                "MELTH",
                "MELTW",
                "SNOW",
                "IOFF",
                "ROFF",
                "EVAP",
                "PREC",
                "SALTFLX",

                "ADVT",
                "ADVS",
                "HMXL",
                "USFC",
                "VSFC",
                
                "WKRSTT",
                "WKRSTS",
     
                "VDIFFT",
                "VDIFFS",

                "Q_FRZMLTPOT",
                "Q_FRZMLTPOT_NEG",
                "Q_FRZHEAT",
                "Q_FRZHEAT_OVERFLOW",
                "CHKTEMP",
                "CHKSALT",

                "QFLXT",
                "QFLXS",
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
            else
                println("$(k) is nothing")
            end
        end
        return subset_dict
    end

    #println("NOW AGAIN: ", output_varnames)

    output_varlist = makeSubset(all_varlist, output_varnames)

    return output_varlist
end



