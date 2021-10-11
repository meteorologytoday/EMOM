include(normpath(joinpath(@__DIR__, "IOM", "src", "models", "EMOM", "EMOM.jl")))
using DataStructures
using NCDatasets
using MPI
using Formatting
using ArgParse, JSON


function runOneCmd(cmd)
    println(">> ", string(cmd))
    run(cmd)
end

function pleaseRun(cmd)
    if isa(cmd, Array)
        for i = 1:length(cmd)
            runOneCmd(cmd[i])
        end
    else
        runOneCmd(cmd)
    end
end


println("""
This program produces (1) init.jld and (2) Nz_bot.nc file given a config file.
Nz_bot.nc is generated through running make_Nz_bot.jl or make_Nz_bot_SOM.jl.

The NaNs of TEMP or SALT variables are assumed masked and thus topo file is 
constructed.

This program also checks if the given initial profiles are consistent, meaning
their NaNs are located exactly at the same grids.
""")

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

        "--HMXL-unit"
            help = "Unit of HMXL. By default I will try to convert it to meters."
            arg_type = String
            required = true

        "--config-file"
            help = "config TOML file"
            arg_type = String
            required = true

        "--SOM"
            help = "If set then data blow Nz_bot will be removed."
            action = :store_true

    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))
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
    if parsed["HMXL-unit"] == "m"
        println("It is already in meters.")
    elseif parsed["HMXL-unit"] == "cm"
        println("It is cm! Convert it...")
        HMXL ./= 100.0
    else
        thorw(ErrorException("Unknown unit: $(parsed["HMXL-unit"])"))
    end

    if any(HMXL .< 0)
        thorw(ErrorException("HMXL cannot be negative."))
    end
end

Nx, Ny = size(TEMP)[2:3]
Nz_bot = zeros(Int64, Nx, Ny)
mask_T = zeros(Float64, Nz, Nx, Ny)
mask_T[isfinite.(TEMP)] .= 1.0
valid_idx = mask_T .== 1.0

println("Making Nz_bot...")
if ! parsed["SOM"]
    println("This is not SOM.")
    Nz_bot .= sum(mask_T, dims=1)[1, :, :]
else
    println("This is SOM.")
    for i=1:Nx, j=1:Ny
        h = HMXL[i, j]
        if isnan(h)
            Nz_bot[i, j] = 0
        else
            Nz_bot[i, j] = findlast(z_w_top .>= - h)  # Use ">=" to avoid h = 0 that makes Nz = 0
        end
    end

end

# Test if Nz_bot is consistent with the mask
mask_from_Nz_bot = copy(Nz_bot)
mask_from_Nz_bot[mask_from_Nz_bot .!= 0] .= 1

println("Check if SOM's Nz_bot is consistent with the mask...")
if all(mask_from_Nz_bot .== mask)
    println("Yes they are consistent.")
else
    throw(ErrorException("Nz_bot and mask not consistent"))
end


println("Check if the NaNs of TEMP, SALT are both consistent")
if any(isfinite.(TEMP) .!= isfinite.(SALT))
    throw(ErrorException("Locations of NaNs of TEMP and SALT mismatch. Please check."))
end


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

