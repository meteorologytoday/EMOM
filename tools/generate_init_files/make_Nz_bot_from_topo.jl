using DataStructures
using NCDatasets
using Formatting
using ArgParse, JSON

println("""
This program generates an netCDF file that contains `Nz_bot` of the topography.
User should provide a `--ref-file` with `--ref-var` to inform the mask of the 3D domain.
If `--SOM` is set, then `--HMXL-file` is used to generate the Nz_bot, meaning the bottom 
of the ocean is as deep as the mixed-layer depth.
""")


s = ArgParseSettings()
@add_arg_table s begin

    "--domain-file"
        help = "Domain file that must contain mask."
        arg_type = String
        required = true

    "--z_w-file"
        help = "Z domain file contains z_w_top, z_w_bot."
        arg_type = String
        required = true

    "--topo-file"
        help = "If not provided, then assume all grids are valid."
        arg_type = String
        default = ""

    "--HMXL-file"
        help = "The file containing HMXL. If --SOM is set then it has to be given."
        arg_type = String
        default = ""

    "--HMXL-unit"
        help = "Unit of HMXL. By default I will try to convert it to meters."
        arg_type = String
        default = "m"

    "--output-file"
        help = "Name of the output Nz file"
        arg_type = String
        default = "Nz_bot.nc"

    "--SOM"
        help = "If set then `HMXL-file` and `HMXL-unit` have to be given."
        arg_type = Bool
        default = false

end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

if parsed["SOM"]
    for optname in ["HMXL-file", "HMXL-unit"]
        if parsed[optname] == ""
            throw(ErrorException("Error: `$(optname)` must be set because `SOM` is set."))
        end
    end
end


Dataset(parsed["z_w-file"], "r") do ds
    global z_w_top = nomissing(ds["z_w_top"][:],  NaN)
    global z_w_bot = nomissing(ds["z_w_bot"][:],  NaN)

    if length(z_w_top) != length(z_w_bot)
        throw(ErrorException("Lengths of z_w_top and z_w_bot do not match."))
    end
    global Nz = length(z_w_top)
end

Dataset(parsed["domain-file"], "r") do ds
    global mask = ds["mask"][:]
    global Nx, Ny = size(mask)
end

if parsed["topo-file"] != ""
    Dataset(parsed["topo-file"], "r") do ds
        global topo = - nomissing(ds["depth"][:],  NaN)
    end
else
    topo = zeros(Float64, Nx, Ny)
    topo .= z_w_bot[end]
end


Nz_bot = zeros(Int64, Nx, Ny)

if parsed["SOM"]

    Dataset(parsed["HMXL-file"], "r") do ds
        global HMXL = reshape(nomissing(ds["HMXL"][:], NaN), Nx, Ny)
        if parsed["HMXL-unit"] == "m"
            println("It is already in meters.")
        elseif parsed["HMXL-unit"] == "cm"
            println("It is cm! Convert it...")
            HMXL ./= 100.0
        else
            println("Unknown unit: $(parsed["HMXL-unit"])")
        end
    end

    for i=1:Nx, j=1:Ny
        h = HMXL[i, j]
        if isnan(h)
            Nz_bot[i, j] = 0
        else
            Nz_bot[i, j] = findlast(z_w_top .>= - h)  # Use ">=" to avoid h = 0 that makes Nz = 0
        end
    end
else
    Nz_bot .= 0
    for i=1:Nx, j=1:Ny
        if mask[i, j] == 1
            _topo = topo[i, j]

            if _topo == 0
                continue
            end

            if _topo < z_w_bot[end]
                Nz_bot[i, j] = Nz
            else 
                for k=1:Nz
                    if z_w_bot[k] <= _topo < z_w_top[k]
                        Nz_bot[i, j] = k
                        break
                    end
                end
            end
        end
    end
end


println("Output file: $(parsed["output-file"]).")
Dataset(parsed["output-file"], "c") do ds

    defDim(ds, "Nx", Nx)
    defDim(ds, "Ny", Ny)
    defVar(ds, "Nz_bot", Nz_bot, ("Nx", "Ny", ), ; attrib = Dict(
        "long_name" => "z-grid idx of the deepest cell",
        "units"     => "none",
    ))

end

# Test if Nz_bot is consistent with the mask
println("Check if Nz_bot is consistent with the mask...")
mask_from_Nz_bot = copy(Nz_bot)
mask_from_Nz_bot[mask_from_Nz_bot .!= 0] .= 1
if all(mask_from_Nz_bot .== mask)
    println("Yes they are consistent.")
else
    throw(ErrorException("Nz_bot and mask not consistent"))
end


