
using DataStructures
using NCDatasets
using Formatting
using ArgParse, JSON

println("""
This program generates an netCDF file that contains `z_w` of the vertical grid.
""")


s = ArgParseSettings()
@add_arg_table s begin

    "--output-file"
        help = "Z domain file contains z_w."
        arg_type = String
        default = "z_w.nc"
    
    "--z_w"
        help = "A list of z_w. It must starts from 0.0 and monotonically decrease."
        arg_type = Float64
        nargs = '+'
        default = [0.0, -10.0]

end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

if length(parsed["z_w"]) < 2
    if parsed[optname] == ""
        throw(ErrorException("Error: `--z_w` must provide at least two values."))
    end
end

z_w = parsed["z_w"]
if z_w[1] != 0.0
    throw(ErrorException("Error: The first value of `--z_w` must be 0.0."))
end


dz = z_w[1:end-1] - z_w[2:end]
if any(dz .<= 0)
    throw(ErrorException("Error: `--z_w` must be monotonically decresing."))
end

println("Output file: $(parsed["output-file"]).")

Dataset(parsed["output-file"], "c") do ds

    defDim(ds, "Nzp1", length(z_w))
    defDim(ds, "Nz", length(z_w)-1)

    defVar(ds, "z_w", z_w, ("Nzp1", ), ; attrib = Dict(
        "long_name" => "The z-coord of the W grid",
        "units"     => "m",
    ))

    defVar(ds, "z_w_top", z_w[1:end-1], ("Nz", ), ; attrib = Dict(
        "long_name" => "The z-coord of top face of the W grid",
        "units"     => "m",
    ))

    defVar(ds, "z_w_bot", z_w[2:end], ("Nz", ), ; attrib = Dict(
        "long_name" => "The z-coord of bottom face of the W grid",
        "units"     => "m",
    ))



end