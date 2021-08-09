
function getConfigDescriptor()

    return Dict(


        :MODEL_MISC => [


            ConfigEntry(
                :init_file,
                :optional,
                [nothing, String],
                nothing
            ),

            ConfigEntry(
                :rpointer_file,
                :optional,
                [String,],
                "";
                desc="If read_restart of the init function is set true, then this entry has to contain a valid rpointer filename.",
            ),

            ConfigEntry(
                :enable_archive,
                :required,
                [Bool,],
            ),


            ConfigEntry(
                :daily_record,
                :optional,
                [AbstractArray,],
                [],
            ),

            ConfigEntry(
                :monthly_record,
                :optional,
                [AbstractArray,],
                [],
            ),

        ],
        
        :MODEL_CORE => [

            ConfigEntry(
                :timetype,
                :optional,
                [String,],
                "DateTimeNoLeap",
            ),

            ConfigEntry(
                :domain_file,
                :required,
                [String,],
            ),

            ConfigEntry(
                :cdata_file,
                :optional,
                [String,],
                nothing,
            ),


            ConfigEntry(
                :cdata_beg_time,
                :optional,
                [Any,],
            ),

            ConfigEntry(
                :cdata_end_time,
                :optional,
                [Any,],
            ),

            ConfigEntry(
                :cdata_align_time,
                :optional,
                [Any,],
            ),


            ConfigEntry(
                :substeps,
                :optional,
                [Integer,],
                8;
            ),

            ConfigEntry(
                :advection_scheme,
                :required,
                [:static, :ekman_codron2012_partition],
            ),

            ConfigEntry(
                :MLD_scheme,
                :required,
                [:prognostic, :datastream, :static],
            ),

            ConfigEntry(
                :Qflx,
                :optional,
                [:on, :off],
                :off,
            ),
            
            ConfigEntry(
                :Qflx_finding,
                :optional,
                [:on, :off],
                :off,
            ),
            
            ConfigEntry(
                :weak_restoring,
                :optional,
                [:on, :off],
                :off,
            ),
            
            ConfigEntry(
                :convective_adjustment,
                :optional,
                [:on, :off],
                :off,
            ),

            ConfigEntry(
                :z_w,
                :optional,
                [AbstractArray{Float64, 1}],
                nothing;
                desc = "Will be overwritten if :init_file is used.",
            ),

            ConfigEntry(
                :Ks_H,
                :optional,
                [Float64,],
                1e3;
                desc = "Horizontal tracer diffusivity. Will be overwritten if :init_file is used.",
            ),

            ConfigEntry(
                :Ks_V,
                :optional,
                [Float64,],
                1e-4;
                desc = "Vertical tracer diffusivity. Will be overwritten if :init_file is used.",
            ),

            ConfigEntry(
                :Ks_V_cva,
                :optional,
                [Float64,],
                1.0;
                desc = "Convective adjustment diffusivity. Will be overwritten if :init_file is used.",
            ),

            ConfigEntry(
                :τwk_TEMP,
                :optional,
                [Float64,],
                Inf;
                desc = "Timescale of weak-restoring of temperature. Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :τwk_SALT,
                :optional,
                [Float64,],
                Inf;
                desc = "Timescale of weak-restoring of salinity. Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :τ_frz,
                :optional,
                [Float64,],
                3600.0;
                desc = "Timescale of freezing when ocean temperature is below T_sw_frz = -1.8 degC. Will be overwritten if :init_file is used",
            ),


            ConfigEntry(
                :rad_R,
                :optional,
                [Float64,],
                0.58;
                desc = "Fast absorption portion of sunlight as described in Paulson & Simpson (1977). Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :rad_ζ1,
                :optional,
                [Float64,],
                0.15;
                desc = "Light penetration length scale as described in Paulson & Simpson (1977). Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :rad_ζ2,
                :optional,
                [Float64,],
                23.0;
                desc = "Light penetration length scale as described in Paulson & Simpson (1977). Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :ϵ,
                :optional,
                [Float64,],
                1.0 / 86400.0;
                desc = "Rayleigh friction of momentum. Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :Ekman_layers,
                :optional,
                [Integer,],
                5;
                desc = "Number of Ekman layers. Will be overwritten if :init_file is used",
            ),

            ConfigEntry(
                :Returnflow_layers,
                :optional,
                [Integer,],
                5;
                desc = "Number of Ekman return flows. Will be overwritten if :init_file is used",
            ),
        ],
    )
end
