overwrite_configs = Dict()

configs = Dict(
    :substeps    => 8,                 # This controls how many steps will occur for each CESM coupling. Example: ocean couple to atmosphere every 24 hours but itself steps every 3 hours. This means we would expect `Δt` = 86400, and we set `substeps` = 8.
    :daily_record              => [],
    :monthly_record            => :ESSENTIAL,
    :enable_archive            => true,
    :archive_list              => "archive_list.txt",
    :rpointer_file             => "rpointer.hoom",
    :timeout                   => 60.0 * 20, 
)

#=
configs = Dict(
    :casename    => "casename",
    :substeps    => 8,                 # This controls how many steps will occur for each CESM coupling. Example: ocean couple to atmosphere every 24 hours but itself steps every 3 hours. This means we would expect `Δt` = 86400, and we set `substeps` = 8.
    :caseroot                  => pwd(),
    :caserun                   => pwd(),
    :domain_file               => "/home/tienyiah/cesm_inputdata/cesm1/share/domains/domain.ocn.gx3v7.120323.nc",
    :daily_record              => [],
    :monthly_record            => :ALL,
    :enable_archive            => true,
    :archive_root              => pwd(),
    :archive_list              => "archive_list.txt",
    :rpointer_file             => "rpointer.hoom",
    :timeout                   => 60.0 * 20, 
)
=#

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--config"
            help = "Configuration file."
            arg_type = String
       
        "--core"
            help = "Core of the model."
            arg_type = String

    end

    return parse_args(s)
end

parsed_args = parse_commandline()
#for (arg,val) in parsed_args
#    println("$arg  =>  ", repr(val))
#end

config_file = parsed_args["config"]
if config_file != nothing
    config_file = normpath( (isabspath(config_file)) ? config_file : joinpath(pwd(), config_file) )
    println("===== Load config file: ", config_file, " =====")
    include(config_file)
end

if !(@isdefined OMMODULE)
    core_name = parsed_args["core"]
    if core_name == nothing
        throw(ErrorException("Core ocean module is not provided. Please set --core option, or define OMMODULE in configuration file."))
    else
        module_name = "CESMCORE_" * core_name
        println("BASE: " * @__FILE__) 
        core_file = normpath(joinpath(dirname(@__FILE__), "..", "models", core_name, module_name * ".jl"))
        println("Selected core: ", core_name, " => ", core_file )
        
        include(core_file)
        OMMODULE = getfield(Main, Symbol(module_name))
    end 
end

println("===== Defining variables BEGIN =====")
for (k, v) in overwrite_configs
    if k in keys(configs)
        println("Overwrite config ", k, "...")
    else
        println("Add config ", k, "...")
    end

    configs[k] = v
end

if ! ( "tmp_folder" in keys(configs) )
    
    configs[:tmp_folder] = joinpath(configs[:caserun], "x_tmp")
    
end


print(json(configs, 4))
println("===== Defining variables END =====")
