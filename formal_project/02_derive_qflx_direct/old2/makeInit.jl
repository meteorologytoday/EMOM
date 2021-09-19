include(normpath(joinpath(@__DIR__, "IOM", "src", "models", "EMOM", "EMOM.jl")))
using NCDatasets
using MPI
using Formatting



using ArgParse, JSON
function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--init-profile-TEMP"
            help = "Initial ocean profile"
            arg_type = String
            required = true

        "--init-profile-SALT"
            help = "Initial ocean profile"
            arg_type = String
            required = true

        "--init-profile-HMXL"
            help = "Initial ocean profile"
            arg_type = String
            required = true

        "--config-file"
            help = "config TOML file"
            arg_type = String
            required = true

    end

    return parse_args(s)
end

parsed = parse_commandline()
JSON.print(parsed,4)

MPI.Init()

println("Processing data...")

using TOML
config = TOML.parsefile(parsed["config-file"])

domain_file = config["MODEL_CORE"]["domain_file"]

init_file  = config["MODEL_MISC"]["init_file"]
topo_file  = config["MODEL_CORE"]["topo_file"]

Nz = length(config["MODEL_CORE"]["z_w"]) - 1 # Layers used. Thickness ≈ 503m

Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = ds["mask"][:]
end

Dataset(parsed["init-profile-TEMP"], "r") do ds
    global TEMP  = permutedims(nomissing(ds["TEMP"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
end

Dataset(parsed["init-profile-SALT"], "r") do ds
    global SALT  = permutedims(nomissing(ds["SALT"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
end

Dataset(parsed["init-profile-HMXL"], "r") do ds
    global HMXL  = nomissing(ds["HMXL"][:, :, 1],  NaN)
end



Nx, Ny = size(TEMP)[2:3]
Nz_bot = zeros(Int64, Nx, Ny)
mask_T = zeros(Float64, Nz, Nx, Ny)
mask_T[isfinite.(TEMP)] .= 1.0
valid_idx = mask_T .== 1.0
Nz_bot .= sum(mask_T, dims=1)[1, :, :]

println(format("Output file: {}.", topo_file))

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


mb.fi.sv[:TEMP][valid_idx] .= TEMP[valid_idx]
mb.fi.sv[:SALT][valid_idx] .= SALT[valid_idx]
mb.fi.HMXL[1, :, :] .= HMXL

println(format("Output file: {}.", init_file))

EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)

