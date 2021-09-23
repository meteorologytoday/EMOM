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
        arg_type = Int64
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
    global z_w = nomissing(ds["z_w"][:],  NaN)
end


Dataset(parsed["ref-file"], "r") do ds
    global ref_var  = permutedims(nomissing(ds[parsed["ref-var"]][:, :, 1:Nz, 1],  NaN), [3, 1, 2])
    
    global Nz, Nx, Ny = size(VAR)

    if parsed["Nz-max"] != -1
        Nz = parsed["Nz-max"]
        ref_var = ref_var[1:Nz, :, :]

        if length(z_w) > Nz + 1
            println("z_w has length ($(length(z_w))) longer than `Nz-max` + 1 ($(Nz+1)). We need to trim it ")
            global z_w = z_w[1:Nz+1]
        end
    end
end


Dataset(parsed["HMXL-file"], "r") do ds
    global HMXL = reshape(nomissing(ds["HMXL"][:], NaN), 1, Nx, Ny)
end



Nz_bot = zeros(Int64, Nx, Ny)

for i=1:Nx, j=1:Ny
    h = HMXL[i, j]
    if isnan(h)
        Nz_bot[i, j] = 0
    else
        Nz_bot[i, j] = findfirst(z_w .> - h)  # Avoid h = 0 that makes Nz = 0
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
