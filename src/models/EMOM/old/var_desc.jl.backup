function getCompleteVariableList(ocn::Ocean)

        return Dict(

            # RECORD
            "Ts"                 => ( toXYZ(ocn.Ts, :zxy),          ("Nx", "Ny", "Nz_bone") ),
            "Ss"                 => ( toXYZ(ocn.Ss, :zxy),          ("Nx", "Ny", "Nz_bone") ),
            "Ts_mixed"           => ( toXYZ(ocn.Ts_mixed, :zxy),    ("Nx", "Ny", "Nz_bone") ),
            "Ss_mixed"           => ( toXYZ(ocn.Ss_mixed, :zxy),    ("Nx", "Ny", "Nz_bone") ),
            "bs"                 => ( toXYZ(ocn.bs, :zxy),          ("Nx", "Ny", "Nz_bone") ),
            "T_ML"               => ( ocn.T_ML,                     ("Nx", "Ny") ),
            "S_ML"               => ( ocn.S_ML,                     ("Nx", "Ny") ),
            "b_ML"               => ( ocn.b_ML,                     ("Nx", "Ny") ),
            "FLDO"               => ( ocn.FLDO,                     ("Nx", "Ny") ),
            "dTdt_ent"           => ( ocn.dTdt_ent,                 ("Nx", "Ny") ),
            "dSdt_ent"           => ( ocn.dSdt_ent,                 ("Nx", "Ny") ),
            "TSAS_clim"          => ( ocn.TSAS_clim,                ("Nx", "Ny") ),
            "SSAS_clim"          => ( ocn.SSAS_clim,                ("Nx", "Ny") ),
            "TFLUX_bot"          => ( ocn.TFLUX_bot,                ("Nx", "Ny") ),
            "SFLUX_bot"          => ( ocn.SFLUX_bot,                ("Nx", "Ny") ),
            "SFLUX_top"          => ( ocn.SFLUX_top,                ("Nx", "Ny") ),
            "TFLUX_DIV_implied"  => ( ocn.TFLUX_DIV_implied,        ("Nx", "Ny") ),
            "SFLUX_DIV_implied"  => ( ocn.SFLUX_DIV_implied,        ("Nx", "Ny") ),
            "qflx2atm"           => ( ocn.qflx2atm,                 ("Nx", "Ny") ),
            "qflx2atm_pos"       => ( ocn.qflx2atm_pos,             ("Nx", "Ny") ),
            "qflx2atm_neg"       => ( ocn.qflx2atm_neg,             ("Nx", "Ny") ),
            "h_ML"               => ( ocn.h_ML,                     ("Nx", "Ny") ),
            "h_MO"               => ( ocn.h_MO,                     ("Nx", "Ny") ),
            "nswflx"             => ( ocn.in_flds.nswflx,           ("Nx", "Ny") ),
            "swflx"              => ( ocn.in_flds.swflx,            ("Nx", "Ny") ),
            "frwflx"             => ( ocn.in_flds.frwflx,           ("Nx", "Ny") ),
            "vsflx"              => ( ocn.in_flds.vsflx,            ("Nx", "Ny") ),
            "qflx_T"             => ( ocn.in_flds.qflx_T,           ("Nx", "Ny") ),
            "qflx_S"             => ( ocn.in_flds.qflx_S,           ("Nx", "Ny") ),
            "ifrac"              => ( ocn.in_flds.ifrac,            ("Nx", "Ny") ),
            "qflx_T_correction"  => ( toXYZ(ocn.qflx_T_correction, :zxy),        ("Nx", "Ny", "Nz_bone") ),
            "qflx_S_correction"  => ( toXYZ(ocn.qflx_S_correction, :zxy),        ("Nx", "Ny", "Nz_bone") ),
            "seaice_nudge_energy" => ( ocn.seaice_nudge_energy,     ("Nx", "Ny") ),
            "Tclim"              => ( ocn.in_flds.Tclim,            ("Nx", "Ny") ),
            "Sclim"              => ( ocn.in_flds.Sclim,            ("Nx", "Ny") ),
            "IFRACclim"          => ( ocn.in_flds.IFRACclim,        ("Nx", "Ny") ),
            "TEMP"               => ( ocn.TEMP,                     ("Nx", "Ny") ),
            "dTEMPdt"            => ( ocn.dTEMPdt,                  ("Nx", "Ny") ),
            "SALT"               => ( ocn.SALT,                     ("Nx", "Ny") ),
            "dSALTdt"            => ( ocn.dSALTdt,                  ("Nx", "Ny") ),
            "fric_u"             => ( ocn.fric_u,                   ("Nx", "Ny") ),
            "taux"               => ( ocn.τx,                       ("Nx", "Ny") ),
            "tauy"               => ( ocn.τy,                       ("Nx", "Ny") ),
            "TFLUX_DEN_x"        => ( toXYZ(ocn.TFLUX_DEN_x, :zxy), ("Nx", "Ny", "Nz_bone") ),
#            "TFLUX_DEN_y"        => ( toXYZ(ocn.TFLUX_DEN_x, :zxy), ("Nx", "Ny", "Nz_bone") ),
            "TFLUX_DEN_z"        => ( toXYZ(ocn.TFLUX_DEN_z, :zxy), ("Nx", "Ny", "NP_zs_bone") ),
            "SFLUX_DEN_z"        => ( toXYZ(ocn.SFLUX_DEN_z, :zxy), ("Nx", "Ny", "NP_zs_bone") ),
            "div"                => ( toXYZ(ocn.div, :zxy),         ("Nx", "Ny", "Nz_bone") ),
            "w_bnd"              => ( toXYZ(ocn.w_bnd, :zxy),       ("Nx", "Ny", "NP_zs_bone") ),
            "u"                  => ( toXYZ(ocn.u, :zxy),           ("Nx", "Ny", "Nz_bone") ),
            "v"                  => ( toXYZ(ocn.v, :zxy),           ("Nx", "Ny", "Nz_bone") ),
            "TFLUX_CONV"         => ( toXYZ(ocn.TFLUX_CONV, :zxy),  ("Nx", "Ny", "Nz_bone") ),
            "SFLUX_CONV"         => ( toXYZ(ocn.SFLUX_CONV, :zxy),  ("Nx", "Ny", "Nz_bone") ),

            # COORDINATE
            "area"               => ( ocn.mi.area,                  ("Nx", "Ny") ),
            "mask"               => ( ocn.mi.mask,                  ("Nx", "Ny") ),
            "frac"               => ( ocn.mi.frac,                  ("Nx", "Ny") ),
            "c_lon"              => ( ocn.mi.xc,                    ("Nx", "Ny") ),
            "c_lat"              => ( ocn.mi.yc,                    ("Nx", "Ny") ),
            "zs_bone"            => ( ocn.zs_bone,                  ("NP_zs_bone",) ),

            # BACKGROUND
            "Ts_clim"            => ( toXYZ(ocn.Ts_clim, :zxy),     ("Nx", "Ny", "Nz_bone") ),
            "Ss_clim"            => ( toXYZ(ocn.Ss_clim, :zxy),     ("Nx", "Ny", "Nz_bone") ),
            "h_ML_min"           => ( ocn.h_ML_min,                 ("Nx", "Ny") ),
            "h_ML_max"           => ( ocn.h_ML_max,                 ("Nx", "Ny") ),
            "topo"               => ( ocn.topo,                     ("Nx", "Ny") ),
            "fs"                 => ( ocn.fs,                       ("Nx", "Ny") ),
            "epsilons"           => ( ocn.ϵs,                       ("Nx", "Ny") ),
            "K_v"                => ( :K_v,                         :SCALAR      ),
            "Dh_T"               => ( :Dh_T,                        :SCALAR      ),
            "Dv_T"               => ( :Dv_T,                        :SCALAR      ),
            "Dh_S"               => ( :Dh_S,                        :SCALAR      ),
            "Dv_S"               => ( :Dv_S,                        :SCALAR      ),
            "we_max"             => ( :we_max,                      :SCALAR      ),
            "R"                  => ( :R,                           :SCALAR      ),
            "zeta"               => ( :ζ,                           :SCALAR      ),
            "Ts_clim_relax_time" => ( :Ts_clim_relax_time,          :SCALAR      ),
            "Ss_clim_relax_time" => ( :Ss_clim_relax_time,          :SCALAR      ),

            # DIAGNOSTIC            
            "total_heat" => ( ocn.diag[:total_heat],                ("scalar",)  ),
            "total_salt" => ( ocn.diag[:total_salt],                ("scalar",)  ),
            "total_heat_budget_residue" => ( ocn.diag[:total_heat_budget_residue], ("scalar",)  ),
            "total_salt_budget_residue" => ( ocn.diag[:total_salt_budget_residue], ("scalar",)  ),
        )
end

function getVarDesc(varname)
    return haskey(HOOM.var_desc, varname) ? HOOM.var_desc[varname] : Dict()
end

function getVariableList(ocn::Ocean, keywords...)

        all_varlist = getCompleteVariableList(ocn)

        output_varnames = []

        for keyword in keywords
            if keyword == :ALL

                append!(output_varnames, keys(all_varlist))

            elseif keyword == :QFLX_FINDING

                append!(output_varnames, [
                    "qflx_T", "qflx_S",
                    "qflx_T_correction", "qflx_S_correction",
                    "Tclim", "Sclim", "IFRACclim",
                    "TSAS_clim", "SSAS_clim",
                    "ifrac",
                ])

            elseif keyword == :ESSENTIAL
                
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

            elseif keyword == :DEBUG
                
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


 
            elseif keyword == :COORDINATE

                append!(output_varnames, [
                    "area",
                    "mask",
                    "frac",
                    "c_lon",
                    "c_lat",
                    "zs_bone", 
                ])

            elseif keyword == :BACKGROUND

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

            elseif keyword == :RECORD
                
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

                throw(ErrorException("Unknown keyword: " * string(keyword)))

            end
        end
        output_varlist = Dict()
        for varname in output_varnames
            output_varlist[varname] = all_varlist[varname]
        end

        return output_varlist
end



