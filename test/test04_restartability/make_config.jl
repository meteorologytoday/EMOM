using NCDatasets

project_root_dir = pwd()
data_dir = joinpath(project_root_dir)
domain_dir = joinpath(project_root_dir)
casename = "Sandbox"

forcing_file = joinpath(data_dir, "ocn_forcing.nc")

config = Dict{Any, Any}(

    "DRIVER" => Dict(
        "casename"           => casename,
        "caseroot"           => joinpath(project_root_dir, casename, "caseroot"),
        "caserun"            => joinpath(project_root_dir, casename, "caserun"),
        "archive_root"       => joinpath(project_root_dir, casename, "archive"),
    ),

    "MODEL_MISC" => Dict(
        "timetype"               => "DateTimeNoLeap",
        "init_file"              => "",
        "rpointer_file"          => "rpointer.iom",
        "daily_record"           => [],
        "monthly_record"         => ["{ESSENTIAL}",],
        "enable_archive"         => true,
    ),

    "MODEL_CORE" => Dict(


        "topo_file"                    => "",

        "cdata_var_file_map"           => Dict(
            "HMXL"      => forcing_file,
            "TEMP"      => forcing_file,
            "SALT"      => forcing_file,
            "QFLX_TEMP" => forcing_file,
            "QFLX_SALT" => forcing_file,
        ),

        "cdata_beg_time"               => "0001-01-01 00:00:00",
        "cdata_end_time"               => "0002-01-01 00:00:00",
        "cdata_align_time"             => "0001-01-01 00:00:00",

        "z_w"                          => nothing,

        "substeps"                     => 8,
        "MLD_scheme"                   => "datastream",
        "Qflx"                         => "on",
        "Qflx_finding"                 => "off",
        "convective_adjustment"        => "on",
        "advection_scheme"             => "ekman_AGA2020_allowU",

        "weak_restoring"               => "on",
        "τwk_TEMP"                     => 86400.0 * 365 * 1000,
        "τwk_SALT"                     => 86400.0 * 365 * 1000,


        "τ_frz"                        => 3600.0,
        "Ekman_layers"                 => 2,
        "Returnflow_layers"            => 8,
    
        "transform_vector_field"       => true,
    ),

    "DOMAIN" => Dict(
        "domain_file"                  => joinpath(domain_dir, "domain.nc"),
        "z_w_file"                     => joinpath(domain_dir, "z_w.nc"),
    ),
)

Dataset("ocn_forcing.nc", "r") do ds

    z_w_top = nomissing(ds["z_w_top"][:], NaN)
    z_w_bot = nomissing(ds["z_w_bot"][:], NaN)

    z_w      = zeros(Float64, length(z_w_top)+1)
    z_w[1:end-1]   = z_w_top
    z_w[end] = z_w_bot[end]

    global config["MODEL_CORE"]["z_w"]  = z_w
end


using TOML

open("config.toml", "w") do io
    TOML.print(io, config)
end
