using NCDatasets
using ArgParse
using JSON
using Formatting

include("./interpolate.jl")

function parse_commandline()

    s = ArgParseSettings()
    @add_arg_table s begin
 
        "--input-file"
            help = "Input file."
            arg_type = String
            required = true

        "--output-file"
            help = "Output file."
            arg_type = String
            required = true

        "--input-zdomain-file"
            help = "Resolution keywords. Currently accept: POP2, Standard."
            arg_type = String
            required = true

        "--input-zdomain-varname"
            help = "Resolution keywords. Currently accept: POP2, Standard."
            arg_type = String
            required = true

        "--output-zdomain-file"
            help = "Resolution keywords. Currently accept: POP2, Standard."
            arg_type = String
            required = true

        "--output-zdomain-varname"
            help = "Resolution keywords. Currently accept: POP2, Standard."
            arg_type = String
            required = true

        "--varname"
            help = "Variable name"
            arg_type = String
            required = true

        "--input-zdomain-type" 
            help = "Currently accept: endpoints, midpoints"
            arg_type = String
            required = true

    end

    return parse_args(ARGS, s)
end

parsed = parse_commandline()
print(json(parsed, 4))


Dataset(parsed["input-zdomain-file"], "r") do ds
    global zs_i = ds[parsed["input-zdomain-varname"]][:] |> nomissing
end

Dataset(parsed["output-zdomain-file"], "r") do ds
    global zs_o = ds[parsed["output-zdomain-varname"]][:] |> nomissing
end

if parsed["input-zdomain-type"] == "endpoints"
    println("Input zdomain use endpoints. Take average.")
    zs_i_mid = (zs_i[2:end] + zs_i[1:end-1] ) / 2.0
elseif parsed["input-zdomain-type"] == "midpoints"
    println("Input zdomain use midpoints. Do nothing.")
    zs_i_mid = copy(zs_i)
    # do nothing
else
    throw(ErrorException("Unknown zdomain type: " * string(parsed["input-zdomain-type"])))
end

zs_o_mid = (zs_o[2:end] + zs_o[1:end-1] ) / 2.0

missing_value = 1e20

ds_i    = Dataset(parsed["input-file"], "r")
ds_o    = Dataset(parsed["output-file"], "c")

Nx = ds_i.dim["Nx"]
Ny = ds_i.dim["Ny"]
Nz_o = length(zs_o) - 1

defDim(ds_o, "Nx", Nx)
defDim(ds_o, "Ny", Ny)
defDim(ds_o, "Nz", Nz_o)
defDim(ds_o, "zs", length(zs_o))
defDim(ds_o, "time", Inf)

for (varname, vardata, dims) in (
    ("zs", zs_o, ("zs",)),
)
    println("varname: ", varname)
    v = defVar(ds_o, varname, Float64, dims)
    v[:] = vardata
end

old_data = replace(ds_i[parsed["varname"]][:], missing=>NaN)
new_data = zeros(Float64, Nx, Ny, Nz_o)

println("size of old_data: ", size(old_data))
println("size of new_data: ", size(new_data))

new_data .= NaN

# interpolation function needs
# monotonic increasing function
depth_i = - zs_i_mid
depth_o = - zs_o_mid


for i=1:Nx, j=1:Ny
   
    # detect rng
    valid_data_cnt = sum(isfinite.(old_data[i, j, :]))
 
    if valid_data_cnt == 0

        continue

    elseif valid_data_cnt == 1  # no interpolation at all
        
        println(format("Special case happens at (i, j) = ({},{})", i, j))
        new_data[i, j, :] .= old_data[i, j, 1]

    else

        new_data[i, j, :] = interpolate(
            depth_i[1:valid_data_cnt],
            old_data[i, j, 1:valid_data_cnt],
            depth_o;
            left_copy=true,
            right_copy=true,
        )

    end

end

new_var = defVar(ds_o, parsed["varname"], Float64, ("Nx", "Ny", "Nz", "time"))
new_var.attrib["_FillValue"] = missing_value
new_var[:, :, :, 1] = new_data

close(ds_i)
close(ds_o)

println("Total data cnt: ", length(new_data))
println("Valid data cnt: ", isfinite.(new_data) |> sum)
println("Data holes cnt: ", isnan.(new_data) |> sum)


