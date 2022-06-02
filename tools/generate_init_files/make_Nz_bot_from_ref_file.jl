
using DataStructures
using NCDatasets
using Formatting
using ArgParse, JSON

s = ArgParseSettings()
@add_arg_table s begin

    "--ref-file"
        help = "The 3D temperature or salinity file. Mask should be missing data."
        arg_type = String
        required = true

    "--ref-var"
        help = "Referenced variable name in `ref-file`."
        arg_type = String
        default = "TEMP"

    "--domain-file"
        help = "Domain file that must contain mask."
        arg_type = String
        required = true

    "--z_w-file"
        help = "Z domain file contains z_w."
        arg_type = String
        required = true

    "--SOM-HMXL-file"
        help = "The file containing HMXL. If --SOM is set then it has to be given."
        arg_type = String
        default = ""

    "--SOM-HMXL-convert-factor"
        help = "Conversion used to multiply HMXL variable and end in meters."
        arg_type = Float64
        default = 1.0

    "--Nz-max"
        help = "The maximum layers in the output."
        arg_type = Int64
        default = -1

    "--output-file"
        help = "Name of the output Nz file"
        arg_type = String
        required = true

    "--crop-with-z_w"
        help = "Crop the reference file with z_w file's dimension."
        arg_type = Bool
        default = false

    "--SOM"
        help = "If set then `SOM-HMXL-file` and `SOM-HMXL-convert-factor` have to be given."
        arg_type = Bool
        default = false
end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

if parsed["SOM"]
    for optname in ["SOM-HMXL-file", "SOM-HMXL-convert-factor"]
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
end

Dataset(parsed["domain-file"], "r") do ds
    global mask = ds["mask"][:]
end

Dataset(parsed["ref-file"], "r") do ds
    global ref_var  = permutedims(nomissing(ds[parsed["ref-var"]][:, :, :, 1],  NaN), [3, 1, 2])
    
    global Nz, Nx, Ny = size(ref_var)

    if Nz == length(z_w_top)
        println("The dimension of input file z_w is consistent with the input reference file.")
    else
        println("The dimension of input file z_w is not consistent with the input reference file.")
        if parsed["crop-with-z_w"]
            println("The option `--crop-with-z_w` is on. Crop it.") 
            ref_var = ref_var[1:length(z_w_top), :, :]
            Nz = length(z_w_top)
        else
            throw(ErrorException("The Nz derived from the z_w file is not consistent with the input file. Please specify `--crop-with-z_w` to crop the domain easily."))
        end
    end

    if parsed["Nz-max"] != -1
        Nz = parsed["Nz-max"]
        ref_var = ref_var[1:Nz, :, :]

        if length(z_w_top) > Nz + 1
            println("z_w_top and z_w_bot has length ($(length(z_w_top))) longer than `Nz-max` + 1 ($(Nz+1)). We need to trim it ")
            global z_w_top = z_w_top[1:Nz+1]
            global z_w_bot = z_w_bot[1:Nz+1]
        end
    end
end

Nz_bot = zeros(Int64, Nx, Ny)

if parsed["SOM"]

    Dataset(parsed["SOM-HMXL-file"], "r") do ds
        global SOM_HMXL = reshape(nomissing(ds["HMXL"][:], NaN), Nx, Ny) * parsed["SOM-HMXL-convert-factor"]
    end

    for i=1:Nx, j=1:Ny
        h = SOM_HMXL[i, j]
        if isnan(h)
            Nz_bot[i, j] = 0
        else
            Nz_bot[i, j] = findlast(z_w_top .>= - h)  # Use ">=" to avoid h = 0 that makes Nz = 0
        end
    end

else
    mask_T = zeros(Float64, Nz, Nx, Ny)
    mask_T[isfinite.(ref_var)] .= 1.0
    valid_idx = mask_T .== 1.0
    Nz_bot .= sum(mask_T, dims=1)[1, :, :]
end




# Test if Nz_bot is consistent with the mask
mask_from_Nz_bot = copy(Nz_bot)
mask_from_Nz_bot[mask_from_Nz_bot .!= 0] .= 1

println("Check if Nz_bot is consistent with the mask...")
if all(mask_from_Nz_bot .== mask)
    println("Yes they are consistent.")
else
    throw(ErrorException("Nz_bot and mask not consistent"))
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
