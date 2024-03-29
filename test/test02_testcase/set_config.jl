using NCDatasets
using DataStructures
using ArgParse
using TOML

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config"
            help = "Configuration file."
            arg_type = String
            required = true

    end

    return parse_args(s)
end

parsed = parse_commandline()


project_root_dir = @__DIR__
data_dir = joinpath(project_root_dir, "data")
domain_dir = joinpath(project_root_dir, "CESM_domains")
casename = "Sandbox"
Nz = 33

update_config = OrderedDict{Any, Any}(

    "DRIVER" => Dict(
        "casename"           => casename,
        "caseroot"           => joinpath(project_root_dir, casename, "caseroot"),
        "caserun"            => joinpath(project_root_dir, casename, "caserun"),
        "archive_root"       => joinpath(project_root_dir, casename, "archive"),
        "compute_QFLX_direct_method" => true,
    ),

    "MODEL_MISC" => Dict(

        "init_file"              => joinpath(data_dir, "init_ocn.jld2"),
        "rpointer_file"          => "rpointer.emom",
        "daily_record"           => ["{ESSENTIAL}",],
        "monthly_record"         => ["{ESSENTIAL}",],
        "enable_archive"         => true,
    ),

    "DOMAIN" => Dict(
        "domain_file"                  => joinpath(domain_dir, "domain.ocn.gx3v7.120323.nc"),
        "Nz_bot_file"                  => joinpath(data_dir, "Nz_bot.nc"),
        "z_w_file"                     => joinpath(data_dir, "z_w.nc"),
    ),

    "MODEL_CORE" => Dict(
        
        "timetype"               => "DateTimeNoLeap",

        "cdata_beg_time"               => "0001-01-01 00:00:00",
        "cdata_end_time"               => "0002-01-01 00:00:00",
        "cdata_align_time"             => "0001-01-01 00:00:00",

        "cdata_var_file_QFLXT"         => joinpath(data_dir, "forcing.nc"),
        "cdata_var_file_QFLXS"         => joinpath(data_dir, "forcing.nc"),
        "cdata_var_file_HMXL"          => joinpath(data_dir, "forcing.nc"),
        "cdata_var_file_USFC"          => joinpath(data_dir, "forcing.nc"),
        "cdata_var_file_VSFC"          => joinpath(data_dir, "forcing.nc"),

        "substeps"                     => 8,
        "MLD_scheme"                   => "static",
        "Qflx"                         => "on",
        "Qflx_finding"                 => "off",
        "convective_adjustment"        => "off",
        "advection_scheme"             => "ekman_AGA2020",

        "weak_restoring"               => "off",
        "τwk_TEMP"                     => 86400.0 * 365 * 1000,
        "τwk_SALT"                     => 86400.0 * 365 * 1000,


        "τfrz"                         => 3600.0,
        "Ekman_layers"                 => 3,
        "Returnflow_layers"            => 7,
    
        "transform_vector_field"       => true,
    ),

)

config = TOML.parsefile(parsed["config"])

for (grpname, grp) in update_config
    if ! haskey(config, grpname)
        throw(ErrorException("Group name `$grpname` does not exist."))
    end
    for (entry_name, val) in grp

        println("Updating $(grpname).$(entry_name) = ", val)
        
        if ! haskey(config[grpname], entry_name)
            throw(ErrorException("Entry name `$entry_name` does not exist."))
        end

        config[grpname][entry_name] = val
    end
end

using TOML

open(parsed["config"], "w") do io
    TOML.print(io, config)
end
