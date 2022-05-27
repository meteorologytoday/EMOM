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

        "--domain-file"
            help = "Domain file."
            arg_type = String
            required = true

        "--Nz_bot-file"
            help = "Domain file."
            arg_type = String
            required = true

        "--z_w-file"
            help = "Domain file."
            arg_type = String
            required = true




    end

    return parse_args(s)
end

parsed = parse_commandline()


project_root_dir = @__DIR__
data_dir = joinpath(project_root_dir, "data")
domain_dir = joinpath(project_root_dir, "CESM_domains")
casename = "dummy"

update_config = OrderedDict{Any, Any}(

    "DRIVER" => Dict(
        "casename"           => casename,
        "caseroot"           => joinpath(project_root_dir, casename, "caseroot"),
        "caserun"            => joinpath(project_root_dir, casename, "caserun"),
        "archive_root"       => joinpath(project_root_dir, casename, "archive"),
    ),

    "MODEL_MISC" => Dict(

        "init_file"              => joinpath(data_dir, "init_ocn.jld2"),
        "rpointer_file"          => "rpointer.iom",
        "daily_record"           => [],
        "monthly_record"         => ["{ESSENTIAL}", "QFLXT", "QFLXS"],
        "enable_archive"         => true,
    ),

    "DOMAIN" => Dict(
        "domain_file"                  => parsed["domain-file"],
        "Nz_bot_file"                  => parsed["Nz_bot-file"],
        "z_w_file"                     => parsed["z_w-file"],
    ),

    "MODEL_CORE" => Dict(
        
        "timetype"               => "DateTimeNoLeap",

        "cdata_beg_time"               => "0001-01-01 00:00:00",
        "cdata_end_time"               => "0002-01-01 00:00:00",
        "cdata_align_time"             => "0001-01-01 00:00:00",

        "substeps"                     =>  8,
        "MLD_scheme"                   => "static",
        "Qflx"                         => "off",
        "Qflx_finding"                 => "off",
        "convective_adjustment"        => "on",
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
