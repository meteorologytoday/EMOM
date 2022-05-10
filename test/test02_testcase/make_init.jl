include(normpath(joinpath(@__DIR__, "EMOM", "src", "dyn_core", "EMOM.jl")))
using NCDatasets
using MPI
using Formatting

MPI.Init()

println("Processing data...")

using TOML
config = TOML.parsefile("data/config.toml")

init_POP_file = "hist/paper2021_POP2_CTL.pop.h.daily.0002-01-01.nc"
domain_file = config["MODEL_CORE"]["domain_file"]

init_file  = config["MODEL_MISC"]["init_file"]
topo_file  = config["MODEL_CORE"]["topo_file"]

Nz = length(config["MODEL_CORE"]["z_w"]) - 1 # Layers used. Thickness ≈ 503m

Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = ds["mask"][:]
end

println("Initial profile uses the first record of $(init_POP_file)")
Dataset(init_POP_file, "r") do ds
    global TEMP  = permutedims(nomissing(ds["TEMP"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    global SALT  = permutedims(nomissing(ds["SALT"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
end

Nx, Ny = size(TEMP)[2:3]
Nz_bot = zeros(Int64, Nx, Ny)
mask_T = zeros(Float64, Nz, Nx, Ny)
mask_T[isfinite.(TEMP)] .= 1.0
valid_idx = mask_T .== 1.0
Nz_bot .= sum(mask_T, dims=1)[1, :, :]

println(format("Output file: {}", topo_file))

Dataset(topo_file, "c") do ds

    defDim(ds, "Nx", Nx)
    defDim(ds, "Ny", Ny)
    defVar(ds, "Nz_bot", Nz_bot, ("Nx", "Ny", ), ; attrib = Dict(
        "long_name" => "z-grid idx of the deepest cell",
        "units"     => "none",
    ))

end


println("Create a model to save initial condition.")

ev = EMOM.Env(config["MODEL_CORE"])
mb = EMOM.ModelBlock(ev; init_core=false)


#mb.fi.sv[:TEMP][valid_idx] .= TEMP[valid_idx]
#mb.fi.sv[:SALT][valid_idx] .= SALT[valid_idx]

mb.fi.sv[:TEMP][valid_idx] .= 10.0
mb.fi.sv[:SALT][valid_idx] .= 30.0

mb.fi[:HMXL][valid_idx] .= 9

#mb.fi.sv[:TEMP][1, :, :] .= 30.0

println(format("Output file: {}", init_file))

EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)

