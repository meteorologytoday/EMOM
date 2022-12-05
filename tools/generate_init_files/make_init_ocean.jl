include(normpath(joinpath(@__DIR__, "..", "..", "src", "dyn_core", "EMOM.jl")))
using DataStructures
using NCDatasets
using MPI
using Formatting
using ArgParse, JSON

println("""
This program generates initial file (technically a restart file) for EMOM to start.
""")


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config"
            help = "config TOML file"
            arg_type = String
            default = ""

        "--output-filename"
            help = "Output filename (jld2 file)."
            arg_type = String
            default = ""

        "--init-profile-TEMP"
            help = "Initial ocean profile. It must contains: TEMP. If not specified, `default-TEMP` is used."
            arg_type = String
            default = ""

        "--init-profile-SALT"
            help = "Initial ocean profile. It must contains: SALT. If not specified, `default-SALT` is used."
            arg_type = String
            default = ""


        "--init-profile-HMXL"
            help = "Initial ocean profile. It must contains: HMXL. If not specified, mixed layer depth is set to 50m."
            arg_type = String
            default = ""

        "--default-TEMP"
            help = "Default temperature if `init-profile-TEMP` is not provided (in degC)."
            arg_type = Float64
            default = 10.0

        "--default-SALT"
            help = "Default salinity if `init-profile-SALT` is not provided (in PSU)."
            arg_type = Float64
            default = 35.0



    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
JSON.print(parsed,4)


MPI.Init()

println("Processing data...")

using TOML
config = TOML.parsefile(parsed["config"])

if parsed["output-filename"] != ""
    init_file  = parsed["output-filename"]
else
    init_file  = config["MODEL_MISC"]["init_file"]
end

domain_file = config["DOMAIN"]["domain_file"]
Nz_bot_file  = config["DOMAIN"]["Nz_bot_file"]
z_w_file = config["DOMAIN"]["z_w_file"]

Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = ds["mask"][:]
end

Dataset(z_w_file, "r") do ds
    global Nz = length(ds["z_w_top"])
end

println("Dimension (Nz, Nx, Ny) = ($Nz, $Nx, $Ny)")
# The last dimension 1 here means the time dimension
# This is for practical purposes because user typically
# pick an output from POP2 and use them as the initial profile file
# The shape of the initial profile is also assumed to be (Nx, Ny, Nz)

if parsed["init-profile-TEMP"] != ""
    Dataset(parsed["init-profile-TEMP"], "r") do ds
        global TEMP = permutedims(nomissing(ds["TEMP"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    end
else
    println("No profile provided. Use the default temperature: ", parsed["default-TEMP"])
    TEMP = zeros(Float64, Nz, Nx, Ny)
    TEMP .= parsed["default-TEMP"]
end

if parsed["init-profile-SALT"] != ""
    Dataset(parsed["init-profile-SALT"], "r") do ds
        global SALT = permutedims(nomissing(ds["SAKT"][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    end
else
    SALT = zeros(Float64, Nz, Nx, Ny)
    println("No profile provided. Use the default salinity: ", parsed["default-SALT"])
    SALT .= parsed["default-SALT"]
end

if parsed["init-profile-HMXL"] != ""
    Dataset(parsed["init-profile-HMXL"], "r") do ds
        global HMXL  = nomissing(ds["HMXL"][:, :, 1],  0.0)
    end
else
    HMXL = zeros(Float64, Nx, Ny)
    HMXL .= 50.0
end

if Nz_bot_file == ""
    Nz_bot = zeros(Int64, Nx, Ny)
    Nz_bot .= Nz
else
    Dataset(Nz_bot_file, "r") do ds
        global Nz_bot = ds["Nz_bot"][:]
    end
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

ev = EMOM.Env(config)
mb = EMOM.ModelBlock(ev; init_core=false)


mb.fi.sv[:TEMP][valid_idx] .= TEMP[valid_idx]
mb.fi.sv[:SALT][valid_idx] .= SALT[valid_idx]

mb.fi.HMXL[:] = HMXL

println(format("Output file: {}.", init_file))
EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, init_file)

