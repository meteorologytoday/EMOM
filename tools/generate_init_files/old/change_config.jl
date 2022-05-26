
include(joinpath(@__DIR__, "..", "..", "src", "share", "Config.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "configs", "domain_configs.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "configs", "driver_configs.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "configs", "EMOM_configs.jl"))


using .Config
using DataStructures
using NCDatasets
using Formatting
using ArgParse, JSON
using TOML

println("""
This program alters the config file. 
""")

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--key"
            help = "Key. The groupname with keyname. For example, `DOMAIN.topo_file`. "
            arg_type = String
            required = true

        "--val"
            help = "Value."
            arg_type = String
            required = true

        "--config"
            help = "Config file. (TOML file)"
            arg_type = String
            required = true

        "--overwrite"
            help = "If set then overwrite the input config file."
            action = :store_true

        "--verbose"
            arg_type = Bool
            default = false
    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
JSON.print(parsed,4)

config = TOML.parsefile(parsed["config"])

av_grpnames = ["MODEL_CORE", "MODEL_MISC", "DOMAIN", "DRIVER"]

domain_cfgd = getDomainConfigDescriptors()
driver_cfgd = getDriverConfigDescriptors()
EMOM_cfgd = getEMOMConfigDescriptors()

cfgd = merge(domain_cfgd, driver_cfgd, EMOM_cfgd)

grpname, entry_name = split(parsed["key"], ".")

if ! haskey(config[grpname], entry_name)
    throw(ErrorException("The key `$entry_name` does not exists in the group `$grpname`."))
end
config[grpname][entry_name] = parsed["val"] 

for grpname in keys(config) 
    config[grpname] = validateConfigEntries(config[grpname], cfgd[grpname]; verbose = parsed["verbose"])
end 




using TOML
if parsed["overwrite"]
    println("Overwriting the config file.")
    open(parsed["config"], "w") do io
        TOML.print(io, config; sorted=true)
    end
else
    TOML.print(config; sorted=true)
end
