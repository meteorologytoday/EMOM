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



Dataset(parsed["ref-file"], "r") do ds
    global ref_var  = permutedims(nomissing(ds[parsed["ref-var"]][:, :, :, 1],  NaN), [3, 1, 2])
    
    global Nz, Nx, Ny = size(ref_var)

    if parsed["Nz-max"] != -1

        Nz = parsed["Nz-max"]
        ref_var = ref_var[1:Nz, :, :]
    end

end

Nz_bot = zeros(Int64, Nx, Ny)
mask_T = zeros(Float64, Nz, Nx, Ny)
mask_T[isfinite.(ref_var)] .= 1.0
valid_idx = mask_T .== 1.0
Nz_bot .= sum(mask_T, dims=1)[1, :, :]

println("Output file: $(parsed["output-file"]).")

Dataset(parsed["output-file"], "c") do ds

    defDim(ds, "Nx", Nx)
    defDim(ds, "Ny", Ny)
    defVar(ds, "Nz_bot", Nz_bot, ("Nx", "Ny", ), ; attrib = Dict(
        "long_name" => "z-grid idx of the deepest cell",
        "units"     => "none",
    ))

end
