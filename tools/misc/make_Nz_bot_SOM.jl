
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

    "--zdomain-file"
        help = "Z domain file contains z_w."
        arg_type = String
        required = true

    "--HMXL-file"
        help = "The file containing HMXL."
        arg_type = String
        required = true

    "--HMXL-unit"
        help = "Unit of HMXL. By default I will try to convert it to meters."
        arg_type = String
        required = true


    "--Nz-max"
        help = "Referenced variable name in `ref-file`."
        arg_type = Int64
        default = -1

    "--output-file"
        help = "Name of the output Nz file"
        arg_type = String
        required = true


end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

Dataset(parsed["zdomain-file"], "r") do ds
    global z_w_top = nomissing(ds["z_w_top"][:],  NaN)
    global z_w_bot = nomissing(ds["z_w_bot"][:],  NaN)

    if length(z_w_top) != length(z_w_bot)
        throw(ErrorException("Lengths of z_w_top and z_w_bot do not match."))
    end
end


Dataset(parsed["ref-file"], "r") do ds
    global ref_var  = permutedims(nomissing(ds[parsed["ref-var"]][:, :, :, 1],  NaN), [3, 1, 2])
    
    global Nz, Nx, Ny = size(ref_var)

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



Nz_bot = zeros(Int64, Nx, Ny)

for i=1:Nx, j=1:Ny
    h = HMXL[i, j]
    if isnan(h)
        Nz_bot[i, j] = 0
    else
        Nz_bot[i, j] = findlast(z_w_top .>= - h)  # Use ">=" to avoid h = 0 that makes Nz = 0
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
