using Formatting
using ArgParse
using JSON
using NCDatasets

function parse_commandline()

    s = ArgParseSettings()
    @add_arg_table s begin

        "--input-file"
            help = "CESM formated domain file."
            arg_type = String
            required = true

        "--output-file"
            help = "Output SCRIP file."
            arg_type = String
            default = ""

        "--center-lon"
            help = "Longitude variable name."
            arg_type = String
            required = true

        "--center-lat"
            help = "Latitude variable name."
            arg_type = String
            required = true
 
        "--corner-lon"
            help = "Longitude variable name."
            arg_type = String
            required = true

        "--corner-lat"
            help = "Latitude variable name."
            arg_type = String
            required = true
 
        "--mask"
            help = "Mask variable name."
            arg_type = String
            default = "mask"
 
        "--area"
            help = "Area variable name."
            arg_type = String
            default = "area"
   
        "--angle-unit"
            help = "Unit of lat, lon. `deg` or `rad`. Default is `deg`."
            arg_type = String
            default = "deg"

        "--mask-value"
            help = "Mask value. Active grids will be set to 1. Inactive grids will be set to 0."
            arg_type = Float64
            required = true
    
        "--all-active"
            action = :store_true

    end

    return parse_args(ARGS, s)
end

println("Running ", @__FILE__)

parsed = parse_commandline()
print(json(parsed, 4))

if parsed["output-file"] == ""
    parsed["output-file"] = format("{:s}.SCRIP.nc", basename(splitext(parsed["input-file"])[1]))
end


Dataset(parsed["input-file"]) do ds

    c = ( parsed["angle-unit"] == "deg" ) ? π/180.0 : 1.0

    global grid_center_lat = reshape(convert(Array{Float64}, replace(ds[parsed["center-lat"]][:], missing=>NaN)) * c, :)
    global grid_center_lon = reshape(convert(Array{Float64}, replace(ds[parsed["center-lon"]][:], missing=>NaN)) * c, :)
    global grid_corner_lat = reshape(convert(Array{Float64}, replace(ds[parsed["corner-lat"]][:], missing=>NaN)) * c, 4, :)
    global grid_corner_lon = reshape(convert(Array{Float64}, replace(ds[parsed["corner-lon"]][:], missing=>NaN)) * c, 4, :)
    global grid_imask      = reshape(convert(Array{Int64},   replace(ds[parsed["mask"]][:],       missing=>NaN)), :)
    global grid_area       = reshape(convert(Array{Float64}, replace(ds[parsed["area"]][:],       missing=>NaN)), :)

    global grid_dims = collect(Int64, size(ds[parsed["center-lat"]]))
    global grid_size = reduce(*, grid_dims)


    if parsed["all-active"]
        println("--all-active is on.")
        grid_imask .= 1.0
    else
        _grid_imask = copy(grid_imask)
        grid_imask[_grid_imask .== parsed["mask-value"]] .= 1.0
        grid_imask[_grid_imask .!= parsed["mask-value"]] .= 0.0
    end
end

println(grid_dims)

Dataset(parsed["output-file"], "c") do ds

    defDim(ds, "grid_size", grid_size)
    defDim(ds, "grid_corners", 4)
    defDim(ds, "grid_rank", 2)

    for (varname, vardata, varnctype, vardim, attrib) in [
        ("grid_dims",        grid_dims,       Int32,   ("grid_rank",),                 Dict()),
        ("grid_center_lat",  grid_center_lat, Float64, ("grid_size",),                 Dict("units" => "radians")),
        ("grid_center_lon",  grid_center_lon, Float64, ("grid_size",),                 Dict("units" => "radians")),
        ("grid_imask",       grid_imask,      Int32,   ("grid_size",),                 Dict("units" => "unitless")),
        ("grid_corner_lat",  grid_corner_lat, Float64, ("grid_corners", "grid_size",), Dict("units" => "radians")),
        ("grid_corner_lon",  grid_corner_lon, Float64, ("grid_corners", "grid_size",), Dict("units" => "radians")),
        ("grid_area",        grid_area,       Float64, ("grid_size",),                 Dict("units" => "radians^2", "long_name" => "area weights")),
    ]
        println("Doing varname:", varname)
        var = defVar(ds, varname, varnctype, vardim)
 
        for (k, v) in attrib
            var.attrib[k] = v
        end

        rng = []
        for i in 1:length(vardim)-1
            push!(rng, Colon())
        end

        push!(rng, 1:size(vardata)[end])
        var[rng...] = vardata

    end

end

