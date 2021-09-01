using NCDatasets

project_root_dir = @__DIR__
data_dir = joinpath(project_root_dir, "data")
domain_dir = joinpath(project_root_dir, "CESM_domains")

config = Dict{Any, Any}(

    "DRIVER" => Dict(
        "casename"           => "Sandbox",
        "caseroot"           => joinpath(project_root_dir, "Sandbox", "caseroot"),
        "caserun"            => joinpath(project_root_dir, "Sandbox", "caserun"),
        "archive_root"       => joinpath(project_root_dir, "Sandbox", "archive"),
    ),

    "MODEL_MISC" => Dict(
        "timetype"               => "DateTimeNoLeap",
        "init_file"              => joinpath(data_dir, "init_ocn.jld2"),
        "rpointer_file"          => "rpointer.iom",
        "daily_record"           => [],
        "monthly_record"         => ["{ESSENTIAL}",],
        "enable_archive"         => true,
    ),

    "MODEL_CORE" => Dict(

        "domain_file"                  => joinpath(domain_dir, "domain.ocn.gx3v7.120323.nc"),
        "topo_file"                    => joinpath(data_dir, "Nz_bot.nc"),
        "cdata_file"                   => joinpath(data_dir, "POP2PROFILE.g37.nc"),

        "cdata_beg_time"               => "0001-01-01 00:00:00",
        "cdata_end_time"               => "0002-01-01 00:00:00",
        "cdata_align_time"             => "0001-01-01 00:00:00",

        "z_w"                          => nothing,

        "substeps"                     => 8,
        "MLD_scheme"                   => "datastream",
        "Qflx"                         => "on",
        "Qflx_finding"                 => "on",
        "convective_adjustment"        => "on",
        "advection_scheme"             => "ekman_AGA2020",

        "weak_restoring"               => "on",
        "τwk_TEMP"                     => 86400.0 * 365 * 100,
        "τwk_SALT"                     => 86400.0 * 365 * 100,


        "τ_frz"                        => 3600.0,
        "Ekman_layers"                 => 5,
        "Returnflow_layers"            => 25,
    
        "transform_vector_field"       => true,
    ),

)

Dataset("data/POP2PROFILE.g16.nc", "r") do ds

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
