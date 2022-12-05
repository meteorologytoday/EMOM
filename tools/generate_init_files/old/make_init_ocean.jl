include(normpath(joinpath(@__DIR__, "..", "..", "src", "models", "EMOM", "EMOM.jl")))
using DataStructures
using NCDatasets
using MPI
using Formatting
using ArgParse, JSON

println("""
This program generates initial file (technically a restart file) and a config file for EMOM to start.
""")


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin


        "--TEMP"
            help = "Initial ocean profile. It must contains variable TEMP. If not specified then TEMP = 20.0 degC."
            arg_type = String
            default = ""

        "--SALT"
            help = "Initial ocean profile. It must contains variable SALT If not specified then SALT = 35.0 PSU."
            arg_type = String
            default = ""

        "--HMXL"
            help = "Initial ocean profile. It must contains variable HMXL. If not specified then HMXL = 50.0 m."
            arg_type = String
            default = ""

        "--domain"
            help = "The domain nc file contains horizontal grid. The lon and lat are in `ni`, `nj` dims. It is a required input."
            arg_type = String
            required = true

        "--z-domain"
            help = "The nc file that contains `z_W` in meters. If not specified then z_W = [0, -10, -20, ..., -100]."
            arg_type = String
            default = ""

        "--topo"
            help = "Topography file containing `Nz_bot`. If not specified then all grid points are not masked."
            arg_type = String
            default = ""



    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
JSON.print(parsed,4)
MPI.Init()

println("Processing data...")

default_TEMP = 20.0
default_SALT = 35.0

Dataset(parsed["domain"], "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = ds["mask"][:]
end

if parsed["z-domain"] != ""
    Dataset(parsed["z-domain"], "r") do ds
        global z_W = nomissing(ds["z_W"][:])
        dz = z_W[1:end-1] - z_W[2:end]
        if any(dz .<= 0)
            throw(ErrorException("The z_W variable in --z-domain file must be monotonically decreasing"))
        end
    end
else
    println("Empty input for --z-domain. Assign z_W = [0, -10, ..., -100].")
    global z_W = collect(Float64, range(0.0, -100.0, length=11))
end

Nz = length(z_W) - 1

if parsed["TEMP"] != ""
    Dataset(parsed["TEMP"], "r") do ds
        global TEMP = permutedims(nomissing(ds["TEMP"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    end
else
    println("Empty input for TEMP. Assign constant temperature as $default_TEMP degC.")
    global TEMP = zeros(Float64, Nz, Nx, Ny)
    TEMP .= default_TEMP
end

if parsed["SALT"] != ""
    Dataset(parsed["SALT"], "r") do ds
        global SALT = permutedims(nomissing(ds["SALT"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    end
else
    println("Empty input for SALT. Assign constant salinity as $default_SALT PSU.")
    global SALT = zeros(Float64, Nz, Nx, Ny)
    SALT .= default_SALT
end

if parsed["HMXL"] != ""
    Dataset(parsed["HMXL"], "r") do ds
        global HMXL  = nomissing(ds["HMXL"][:, :, 1],  0.0)
    end
else
    println("Empty input for HMXL. Assign constant mixed-layer thickness as $default_HMXL m.")
    global HMXL = zeros(Float64, Nx, Ny)
    HMXL .= default_HMXL
end

if parsed["topo"] != ""
    Dataset(parsed["topo"], "r") do ds
        global Nz_bot  = nomissing(ds["Nz_bot"][:, :],  0)
    end
else
    println("Empty input for topo. Assign Nz_bot = Nz = $Nz.")
    global Nz_bot = zeros(Int64, Nx, Ny)
    Nz_bot .= Nz
end


valid_idx = isfinite.(TEMP)
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

println(size(mb.fi.HMXL))
println(size(HMXL))
mb.fi.HMXL[:] = HMXL

println(format("Output file: {}.", init_file))

EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)

println(format("Output file: {}.", init_file))
EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)


output_config = "DOMAIN.toml"
using TOML
println("Output file: $(output_config)")
open(output_config, "w") do io
    TOML.print(io, domain_config; sorted=true)
end
