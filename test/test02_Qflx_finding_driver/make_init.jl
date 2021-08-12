include(normpath(joinpath(@__DIR__, "IOM", "src", "models", "EMOM", "EMOM.jl")))
using NCDatasets
using MPI

MPI.Init()

println("Processing data...")

include("config.jl")

init_POP_file = config[:MODEL_CORE][:cdata_file]
domain_file = config[:MODEL_CORE][:domain_file]

zdomain_file = init_POP_file
output_file = "ocn_init.nc"

N_layers = 33 # Layers used. Thickness ≈ 503m

Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = ds["mask"][:]
end

Dataset(init_POP_file, "r") do ds
    global TEMP  = permutedims(nomissing(ds["TEMP"][:, :, 1:N_layers, 1],  0.0), [3, 1, 2])
    global SALT  = permutedims(nomissing(ds["SALT"][:, :, 1:N_layers, 1], 35.0), [3, 1, 2])
end



ev = EMOM.Env(config[:MODEL_CORE])
mb = EMOM.ModelBlock(ev; init_core=false)

mb.fi.sv[:TEMP] .= TEMP
mb.fi.sv[:SALT] .= SALT

EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, "init_ocn.jld2")
