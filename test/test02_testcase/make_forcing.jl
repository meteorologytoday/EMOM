using CFTime
using NCDatasets
using Dates
using TOML


# HMXL QFLXT QFLXS TEMP SALT USFC VSFC
config = TOML.parsefile("data/config.toml")

Dataset(config["DOMAIN"]["domain_file"], "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global lon = ds["xc"][:]
    global lat = ds["yc"][:]

    lon = reshape(lon, size(lon)..., 1, 1) .|> deg2rad 
    lat = reshape(lat, size(lat)..., 1, 1) .|> deg2rad

end


Dataset(config["DOMAIN"]["z_w_file"], "r") do ds
    z_w = ds["z_w"][:]
    z_t = 0.5*(z_w[1:end-1] + z_w[2:end])
    global Nz = length(z_t)
    global z_T = reshape(z_t, 1, 1, length(z_t), 1)
end

output_file = joinpath("data", "forcing.nc")
println("Making forcing file: $(output_file)")

period = 365
t = (range(0, period, length=74) |> collect)[1:end-1]
t0 = 0.0

cost = cos.( (t .- t0) / 365.0 * 2π)
sint = sin.( (t .- t0) / 365.0 * 2π)

cost = reshape(cost, 1, 1, 1, :)
sint = reshape(sint, 1, 1, 1, :)

# shape (x, y, z, time)
HMXL = 50 .+ 5 .* cost .* sin.(lat * 2) .* sin.(lon)
USFC = 2  .+ 1 .* cost .* sin.(lat * 2) .* sin.(lon)
VSFC =     0.1 .* cost .* sin.(lon)

TEMP = 10 .+ 5 .* exp.(z_T/30.0) .* sint .* sin.(lon * 2)
SALT = 35 .- 2 .* exp.(z_T/50.0) .* cost .* cos.(lon * 3)

QFLXT = (100 .- 50 .* exp.(z_T/70.0)  .* sint .* sin.(lon * 2)) / 3996 / 1024
QFLXS = (1   .- 0.5 .* exp.(z_T/60.0) .* cost .* sin.(lon * 3)) / 86400.0

Dataset(output_file, "c") do ds

    defDim(ds, "Nx", Nx)
    defDim(ds, "Ny", Ny)
    defDim(ds, "Nz", Nz)
    defDim(ds, "time", Inf)

    for (varname, vardata, vardim, attrib) in [
        ("HMXL",  HMXL, ("Nx", "Ny", "time",), Dict()),
        ("USFC",  USFC, ("Nx", "Ny", "time",), Dict()),
        ("VSFC",  VSFC, ("Nx", "Ny", "time",), Dict()),
        ("TEMP",  TEMP, ("Nx", "Ny", "Nz", "time",), Dict()),
        ("SALT",  SALT, ("Nx", "Ny", "Nz", "time",), Dict()),
        ("QFLXT", QFLXT, ("Nx", "Ny", "Nz", "time",), Dict()),
        ("QFLXS", QFLXS, ("Nx", "Ny", "Nz", "time",), Dict()),
        ("time",  t, ("time",), Dict(
            "calendar" => "noleap",
            "units"    => "days since 0001-01-01 00:00:00",
        )),
    ]
        println("Doing varname:", varname)
        var = defVar(ds, varname, Float64, vardim)
        var.attrib["_FillValue"] = 1e20
        
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

