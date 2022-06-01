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

update_config = OrderedDict{Any, Any}(
    "MODEL_CORE" => Dict(
        "Qflx"                         => "off",
        "Qflx_finding"                 => "on",
        "weak_restoring"               => "off",
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
