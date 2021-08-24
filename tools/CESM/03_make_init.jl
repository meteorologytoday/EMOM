include(normpath(joinpath(@__DIR__, "IOM", "src", "models", "EMOM", "EMOM.jl")))
using NCDatasets
using MPI
using Formatting
using ArgParse


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config-file"
            help = "Config file used to to produce a snapshot file."
            arg_type = String
            required = true

    end

    return parse_args(s)
end

parsed = parse_commandline()




MPI.Init()

println("Processing data...")

include(parsed["config-file"])

init_POP_file = config[:MODEL_CORE][:cdata_file]
domain_file = config[:MODEL_CORE][:domain_file]
init_file  = config[:MODEL_MISC][:init_file]

Nz = length(config[:MODEL_CORE][:z_w]) - 1

Dataset(init_POP_file, "r") do ds
    global TEMP  = permutedims(nomissing(ds["TEMP"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    global SALT  = permutedims(nomissing(ds["SALT"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
end

valid_idx = isfinite.(TEMP)

println("Create a model to save initial condition.")

ev = EMOM.Env(config[:MODEL_CORE])
mb = EMOM.ModelBlock(ev; init_core=false)

mb.fi.sv[:TEMP][valid_idx] .= TEMP[valid_idx]
mb.fi.sv[:SALT][valid_idx] .= SALT[valid_idx]


output_dir = dirname(init_file)
mkpath(dirname(init_file))

println(format("Output file: {}.", init_file))
EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)
