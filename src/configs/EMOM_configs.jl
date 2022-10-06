
function getEMOMConfigDescriptors()

    return Dict(
        "MODEL_MISC" => [


            ConfigEntry(
                "init_file",
                :optional,
                [String],
                "",
            ),

            ConfigEntry(
                "rpointer_file",
                :optional,
                [String,],
                "rpointer.iom";
                desc="If read_restart of the init function is set true, then this entry has to contain a valid rpointer filename.",
            ),

            ConfigEntry(
                "enable_archive",
                :required,
                [Bool,],
                true,
            ),


            ConfigEntry(
                "daily_record",
                :optional,
                [AbstractArray,],
                [],
            ),

            ConfigEntry(
                "monthly_record",
                :optional,
                [AbstractArray,],
                [],
            ),

        ],
        
        "MODEL_CORE" => [

            ConfigEntry(
                "timetype",
                :optional,
                [String,],
                "DateTimeNoLeap",
            ),

            ConfigEntry(
                "cdata_var_file_TEMP",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "cdata_var_file_SALT",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "cdata_var_file_HMXL",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "cdata_var_file_QFLXS",
                :optional,
                [String,],
                "",
            ),
 
            ConfigEntry(
                "cdata_var_file_QFLXT",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "cdata_var_file_USFC",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "cdata_var_file_VSFC",
                :optional,
                [String,],
                "",
            ),

            ConfigEntry(
                "cdata_beg_time",
                :optional,
                [Any,],
                "0000-01-01 00:00:00",
            ),

            ConfigEntry(
                "cdata_end_time",
                :optional,
                [Any,],
                "0001-01-01 00:00:00",
            ),

            ConfigEntry(
                "cdata_align_time",
                :optional,
                [Any,],
                "0000-01-01 00:00:00",
            ),


            ConfigEntry(
                "substeps",
                :optional,
                [Integer,],
                8;
            ),

            ConfigEntry(
                "advection_scheme",
                :required,
                ["static", "ekman_KSC2018", "ekman_CO2012", "ekman_AGA2020", "ekman_AGA2020_allowU"],
                "static",
            ),

            ConfigEntry(
                "MLD_scheme",
                :required,
                ["prognostic", "datastream", "static", "SOM"],
                "static",
            ),

            ConfigEntry(
                "UVSFC_scheme",
                :required,
                ["prognostic", "datastream", "static"],
                "static",
            ),


            ConfigEntry(
                "Qflx",
                :optional,
                ["on", "off"],
                "off",
            ),
            
            ConfigEntry(
                "Qflx_finding",
                :optional,
                ["on", "off"],
                "off",
            ),
            
            ConfigEntry(
                "weak_restoring",
                :optional,
                ["on", "off"],
                "off",
            ),
            
            ConfigEntry(
                "convective_adjustment",
                :optional,
                ["on", "off"],
                "off",
            ),

            ConfigEntry(
                "Ks_H",
                :optional,
                [Float64,],
                1e3;
                desc = "Horizontal tracer diffusivity. Will be overwritten if `init_file` is used.",
            ),

            ConfigEntry(
                "Ks_V",
                :optional,
                [Float64,],
                1e-4;
                desc = "Vertical tracer diffusivity. Will be overwritten if `init_file` is used.",
            ),

            ConfigEntry(
                "Ks_V_cva",
                :optional,
                [Float64,],
                1.0;
                desc = "Convective adjustment diffusivity. Will be overwritten if `init_file` is used.",
            ),

            ConfigEntry(
                "τwk_TEMP",
                :optional,
                [Float64,],
                Inf;
                desc = "Timescale of weak-restoring of temperature. Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "τwk_SALT",
                :optional,
                [Float64,],
                Inf;
                desc = "Timescale of weak-restoring of salinity. Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "τwk_file",
                :optional,
                [String,],
                "";
                desc = "If non-empty then the timescale of weak-restoring of both TEMP and SALT will be read from the specified netCDF file (in seconds)",
            ),

            ConfigEntry(
                "τfrz",
                :optional,
                [Float64,],
                3600.0;
                desc = "Timescale of surface water below freezing point.",
            ),


            ConfigEntry(
                "rad_R",
                :optional,
                [Float64,],
                0.58;
                desc = "Fast absorption portion of sunlight as described in Paulson & Simpson (1977). Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "rad_ζ1",
                :optional,
                [Float64,],
                0.15;
                desc = "Light penetration length scale as described in Paulson & Simpson (1977). Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "rad_ζ2",
                :optional,
                [Float64,],
                23.0;
                desc = "Light penetration length scale as described in Paulson & Simpson (1977). Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "ϵ",
                :optional,
                [Float64,],
                1.4e-5;
                desc = "Rayleigh friction of momentum. Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "γ",
                :optional,
                [Float64,],
                0.06;
                desc = "Rayleigh friction of momentum. Will be overwritten if `init_file` is used",
            ),


            ConfigEntry(
                "Ekman_layers",
                :optional,
                [Integer,],
                5;
                desc = "Number of Ekman layers. Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "Returnflow_layers",
                :optional,
                [Integer,],
                5;
                desc = "Number of Ekman return flows. Will be overwritten if `init_file` is used",
            ),

            ConfigEntry(
                "transform_vector_field",
                :optional,
                [Bool,],
                true;
                desc = "If this is set true, then TAUX_east and TAUY_north are considered pointing to true east and north. Thus, a vector transformation onto grid-x and -y direction will be performed. If this is set false, TAUX_east and TAUY_north are considered aligned with grid-x and -y so no transformation will be performed.",
            ),


        ],
    )
end
