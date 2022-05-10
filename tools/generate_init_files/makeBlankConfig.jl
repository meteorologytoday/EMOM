include(joinpath("..", "..", "src", "share", "Config.jl"))

using .Config
using NCDatasets
using DataStructures
using ArgParse, JSON
using DataStructures


include(joinpath("..", "..", "src", "configs", "domain_configs.jl"))
include(joinpath("..", "..", "src", "configs", "driver_configs.jl"))
include(joinpath("..", "..", "src", "configs", "EMOM_configs.jl"))


"""
This program makes a blank config.
"""

domain_cfgd = getDomainConfigDescriptors()
driver_cfgd = getDriverConfigDescriptors()
EMOM_cfgd = getEMOMConfigDescriptors()

cfgd = merge(domain_cfgd, driver_cfgd, EMOM_cfgd)

cfgs = OrderedDict()

for (cfg_grpname, cfg_entries) in cfgd

    local d = OrderedDict()

    for entry in cfg_entries
        d[entry.name] = entry.default
    end


    cfgs[cfg_grpname] = d
end



using TOML
TOML.print(cfgs; sorted=true)
