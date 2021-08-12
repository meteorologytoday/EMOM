using NCDatasets
using Formatting
using ArgParse
using JSON
include("./HOOM_z_res.jl")


function parse_commandline()

    s = ArgParseSettings()
    @add_arg_table s begin
 
        "--output-file"
            help = "Output file."
            arg_type = String
            required = true

        "--resolution"
            help = "Resolution keywords. Currently accept: POP2, Standard."
            arg_type = String
            required = true
 
    end

    return parse_args(ARGS, s)
end

parsed = parse_commandline()
print(json(parsed, 4))

zs = getHOOMResolution(parsed["resolution"])

Nz = length(zs) - 1
N_zs = length(zs)

Dataset(parsed["output-file"], "c") do ds

    defDim(ds, "Nz", Nz)
    defDim(ds, "zs", N_zs)

    defVar(ds, "zs", zs, ("zs",))
    defVar(ds, "mid_zs", (zs[1:end-1] + zs[2:end]) / 2.0, ("Nz",))
    
end
