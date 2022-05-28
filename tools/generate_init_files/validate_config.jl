
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

        "--config"
            help = "Config file. (TOML file)"
            arg_type = String
            required = true

        "--verbose"
            help = "To be or not to be."
            arg_type = Bool
            default = true
        
        "--validate-groups"
            help = "The group names user wants to validate."
            arg_type = String
            nargs = '*'
            default = ["MODEL_CORE", "MODEL_MISC", "DOMAIN", "DRIVER"]

    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
JSON.print(parsed,4)

config = TOML.parsefile(parsed["config"])

av_grpnames = parsed["validate-groups"]

domain_cfgd = getDomainConfigDescriptors()
driver_cfgd = getDriverConfigDescriptors()
EMOM_cfgd = getEMOMConfigDescriptors()

cfgd = merge(domain_cfgd, driver_cfgd, EMOM_cfgd)

for grpname in keys(config) 
    config[grpname] = validateConfigEntries(config[grpname], cfgd[grpname]; verbose = parsed["verbose"])
end 

println("Done.")
