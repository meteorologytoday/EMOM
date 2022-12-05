include(normpath(joinpath(@__DIR__, "..", "..", "src", "models", "EMOM", "EMOM.jl")))
using DataStructures
using NCDatasets
using MPI
using Formatting
using ArgParse, JSON

println("""
This program generates initial file (technically a restart file) for 
IOM to start.
""")


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config-file"
            help = "config TOML file"
            arg_type = String
            required = true


        "--init-profile-TEMP"
            help = "Initial ocean profile. It must contains: TEMP."
            arg_type = String
            default = ""



        "--init-profile-SALT"
            help = "Initial ocean profile. It must contains: SALT."
            arg_type = String
            default = ""


        "--init-profile-HMXL"
            help = "Initial ocean profile. It must contains: HMXL."
            arg_type = String
            default = ""


    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
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
    global TEMP = permutedims(nomissing(ds["TEMP"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
end

Dataset(parsed["init-profile-SALT"], "r") do ds
    global SALT = permutedims(nomissing(ds["SALT"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
end


Dataset(parsed["init-profile-HMXL"], "r") do ds
    global HMXL  = nomissing(ds["HMXL"][:, :, 1],  0.0)
end

valid_idx = isfinite.(TEMP)

Dataset(topo_file, "r") do ds
    global Nz_bot = ds["Nz_bot"][:]
end

println("Check if all the valid grid will be assigned a non-NaN value.")
for i=1:Nx, j=1:Ny
    local Nz = Nz_bot[i, j]

    if !isfinite(HMXL[i, j])
        throw(ErrorException("Error: Grid ($i, $j) of HMXL is assigned an NaN."))
    end

    for k=1:Nz
        if !isfinite(TEMP[k, i, j])
            throw(ErrorException("Error: Grid ($k, $i, $j) of TEMP is assigned an NaN."))
        end

        if !isfinite(SALT[k, i, j])
            throw(ErrorException("Error: Grid ($k, $i, $j) of SALT is assigned an NaN."))
        end

    end
end
println("NaNs are consistent.")

println("Create a model to save initial condition.")

ev = EMOM.Env(config["MODEL_CORE"])
mb = EMOM.ModelBlock(ev; init_core=false)


mb.fi.sv[:TEMP][valid_idx] .= TEMP[valid_idx]
mb.fi.sv[:SALT][valid_idx] .= SALT[valid_idx]
mb.fi.HMXL[:] = HMXL

println(format("Output file: {}.", init_file))
EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)

