function getCompleteVariableList(
    mb      :: ModelBlock,
    vartype :: Symbol,
)

    d = nothing

    if vartype == :dynamic
        d = Dict(

            # RECORD
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
            "HMXL"               => ( mb.fi.HMXL,          :sT ),
            
            "Q_FRZMLTPOT"        => ( mb.fi.Q_FRZMLTPOT,  :sT ),
            "CHKTEMP"            => ( mb.tmpfi.sv[:CHKTEMP],  :sT ),
            "CHKSALT"            => ( mb.tmpfi.sv[:CHKSALT],  :sT ),
        )
        
        if mb.fi.datastream != nothing 

            if mb.ev.config[:weak_restoring] == :on
                d["WKRST_TEMP"] = ( mb.fi.datastream["WKRST_TEMP"], :T )
                d["WKRST_SALT"] = ( mb.fi.datastream["WKRST_SALT"], :T )
            end

            if mb.ev.config[:Qflx] == :on
                d["QFLX_TEMP"] = ( mb.fi.datastream["QFLX_TEMP"], :T )
                d["QFLX_SALT"] = ( mb.fi.datastream["QFLX_SALT"], :T )
            end

        end

    elseif vartype == :static

        d = Dict(
            # COORDINATEi
#=
            "area"               => ( ocn.mi.area,                  ("Nx", "Ny") ),
            "mask"               => ( ocn.mi.mask,                  ("Nx", "Ny") ),
            "frac"               => ( ocn.mi.frac,                  ("Nx", "Ny") ),
            "c_lon"              => ( ocn.mi.xc,                    ("Nx", "Ny") ),
            "c_lat"              => ( ocn.mi.yc,                    ("Nx", "Ny") ),
            "zs_bone"            => ( ocn.zs_bone,                  ("NP_zs_bone",) ),
=#
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

        elseif varset == :QFLX_FINDING

            append!(output_varnames, [
                "qflx_T", "qflx_S",
                "qflx_T_correction", "qflx_S_correction",
                "Tclim", "Sclim", "IFRACclim",
                "TSAS_clim", "SSAS_clim",
                "ifrac",
            ])

        elseif varset == :ESSENTIAL
            
            append!(output_varnames, [
                "T_ML", "S_ML",
                "Ts_mixed", "Ss_mixed",
                "TSAS_clim", "SSAS_clim",
                "TFLUX_bot", "SFLUX_bot",
                "SFLUX_top",
                "TFLUX_DIV_implied", "SFLUX_DIV_implied",
                "qflx2atm_pos", "qflx2atm_neg",
                "h_ML", "ifrac",
                "nswflx", "swflx", "frwflx", "vsflx",
                "qflx_T", "qflx_S",
                "seaice_nudge_energy",
                "TEMP", "dTEMPdt", "SALT", "dSALTdt",
                "fric_u", "taux", "tauy",
                "TFLUX_DEN_z", "SFLUX_DEN_z",
                "div",
                "w_bnd", "u", "v", "TFLUX_CONV", "SFLUX_CONV",
                "total_heat", "total_heat_budget_residue",
                "total_salt", "total_salt_budget_residue",
            ])

        elseif varset == :DEBUG
            
            append!(output_varnames, [
                "Ts", "Ss", "T_ML", "S_ML", "b_ML", "bs", "FLDO", "h_MO",
                "Ts_mixed", "Ss_mixed",
                "TSAS_clim", "SSAS_clim",
                "TFLUX_bot", "SFLUX_bot",
                "SFLUX_top",
                "TFLUX_DIV_implied", "SFLUX_DIV_implied",
                "qflx2atm_pos", "qflx2atm_neg",
                "h_ML", "ifrac",
                "nswflx", "swflx", "frwflx", "vsflx",
                "qflx_T", "qflx_S",
                "seaice_nudge_energy",
                "TEMP", "dTEMPdt", "SALT", "dSALTdt",
                "fric_u", "taux", "tauy",
                "TFLUX_DEN_z", "SFLUX_DEN_z",
                "div",
                "w_bnd", "u", "v", "TFLUX_CONV", "SFLUX_CONV",
            ])



        elseif varset == :COORDINATE

            append!(output_varnames, [
                "area",
                "mask",
                "frac",
                "c_lon",
                "c_lat",
                "zs_bone", 
            ])

        elseif varset == :BACKGROUND

            append!(output_varnames, [
                "Ts_clim",
                "Ss_clim",
                "h_ML_min",
                "h_ML_max",
                "topo",
                "fs",
                "epsilons",
                "K_v",
                "Dh_T",
                "Dv_T",
                "Dh_S",
                "Dv_S",
                "we_max",
                "R",
                "zeta",
                "Ts_clim_relax_time",
                "Ss_clim_relax_time",
            ])

        elseif varset == :RECORD
            
            # These are variables used in snapshot in order
            # to be restored for restart run Record.
            
            append!(output_varnames, [
                "Ts",
                "Ss",
                "bs",
                "T_ML",
                "S_ML",
                "dTdt_ent",
                "dSdt_ent",
                "TSAS_clim",
                "SSAS_clim",
                "TFLUX_bot",
                "SFLUX_bot",
                "SFLUX_top",
                "TFLUX_DIV_implied",
                "SFLUX_DIV_implied",
                "qflx2atm",
                "qflx2atm_pos",
                "qflx2atm_neg",
                "h_ML",
                "h_MO",
                "nswflx",
                "swflx",
                "frwflx",
                "vsflx",
                "qflx_T",
                "qflx_S",
                "qflx_T_correction",
                "qflx_S_correction",
                "Tclim",
                "Sclim",
                "IFRACclim",
                "TEMP",
                "dTEMPdt",
                "SALT",
                "dSALTdt",
                "fric_u",
                "taux",
                "tauy",
                "TFLUX_DEN_z",
                "SFLUX_DEN_z",
                "div",
                "w_bnd",
                "u",
                "v",
                "TFLUX_CONV",
                "SFLUX_CONV",
            ])
        else

            throw(ErrorException("Unknown varset: " * string(varset)))

        end
    end


    function makeSubset(dict, keys)
        subset_dict = Dict()
        for k in keys
            subset_dict[k] = dict[k]
        end
        return subset_dict
    end


    output_varlist = makeSubset(all_varlist, output_varnames)

    return output_varlist
end



