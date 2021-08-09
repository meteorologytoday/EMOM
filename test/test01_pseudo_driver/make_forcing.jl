using NCDatasets
using CFTime
using Dates

output_file = "forcing.nc"
domain_file = "domain.ocn_aqua.fv4x5_gx3v7.091218.nc"
z_w = collect(Float64, 0:-10:-350)


Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global lat = ds["yc"][:]
    global lon = ds["xc"][:]
    global mask = convert(Array{Float64}, replace(ds["mask"][:], missing=>NaN))
end

Nz = length(z_w) - 1

dom = [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]
sum(dom) == 365 || throw(ErrorException("Sum is not 365"))

beg_of_mon = zeros(Float64, 12)
for m = 2:12
    beg_of_mon[m] = beg_of_mon[m-1] + dom[m-1]
end

mid_of_mon = [ beg_of_mon[m] + dom[m]/2.0 for m=1:12 ]


HMXL = zeros(Float64, Nx, Ny, 12)
WKRST_TEMP = zeros(Float64, Nx, Ny, Nz, 12)
WKRST_SALT = zeros(Float64, Nx, Ny, Nz, 12)
QFLX_TEMP = zeros(Float64, Nx, Ny, Nz, 12)
QFLX_SALT = zeros(Float64, Nx, Ny, Nz, 12)


for t=1:12
    HMXL[:, :, t] = 50.0 .+ 25.0 * sin.(2*deg2rad.(lon) .+ deg2rad.(lat) .- 2π/365 * mid_of_mon[t])
    WKRST_TEMP[:, :, :, t] = ( 20.0 .+
         5.0 * reshape( (1.0 .+ sin.(2*deg2rad.(lon) .+ deg2rad.(lat) .- 2π/365 * mid_of_mon[t]) ) / 2.0, Nx, Ny, 1 ) .* reshape(exp.(z_w[1:end-1] / 100.0), 1, 1, :)
    )
    WKRST_SALT[:, :, :, t] = ( 34.0 .+
         5.0 * reshape( (1.0 .+ sin.(2*deg2rad.(lon) .+ deg2rad.(lat) .- 2π/365 * mid_of_mon[t]) ) / 2.0, Nx, Ny, 1 ) .* reshape(exp.(z_w[1:end-1] / 100.0), 1, 1, :)
    )

    QFLX_TEMP[:, :, :, t] = ( 15 .+
         5.0 * reshape( (1.0 .+ sin.(5*deg2rad.(lon) .+ 2*deg2rad.(lat) .- 5π/365 * mid_of_mon[t]) ) / 2.0, Nx, Ny, 1 ) .* reshape(exp.(z_w[1:end-1] / 100.0), 1, 1, :)
    )

    QFLX_SALT[:, :, :, t] = ( 5 .+
         5.0 * reshape( (1.0 .+ sin.(5*deg2rad.(lon) .+ 2*deg2rad.(lat) .- 5π/365 * mid_of_mon[t]) ) / 2.0, Nx, Ny, 1 ) .* reshape(exp.(z_w[1:end-1] / 100.0), 1, 1, :)
    )





end

Dataset(output_file, "c") do ds

    defDim(ds, "time", Inf)
    defDim(ds, "nlon", Nx)
    defDim(ds, "nlat", Ny)
    defDim(ds, "z_t",  Nz)

    for (varname, vardata, vardim, attrib) in [

        ("time", mid_of_mon, ("time",), Dict(
            "units"     => "days since 0001-01-01 00:00:00",
            "calendar"  => "noleap",
            "long_name" => "total seaice area",
        )),

        ("HMXL", HMXL, ("nlon", "nlat", "time",), Dict(
            "units"     => "m",
            "long_name" => "Mixed layer depth",
        )),

        ("WKRST_TEMP", WKRST_TEMP, ("nlon", "nlat", "z_t", "time",), Dict(
            "units"     => "degC",
            "long_name" => "Temperature",
        )),

        ("WKRST_SALT", WKRST_SALT, ("nlon", "nlat", "z_t", "time",), Dict(
            "units"     => "PSU",
            "long_name" => "Salinity",
        )),

        ("QFLX_TEMP", QFLX_TEMP, ("nlon", "nlat", "z_t", "time",), Dict(
            "units"     => "degC",
            "long_name" => "Temperature QFLX",
        )),

        ("QFLX_SALT", QFLX_SALT, ("nlon", "nlat", "z_t", "time",), Dict(
            "units"     => "degC",
            "long_name" => "Salinity QFLX",
        )),


    ]

        var = defVar(ds, varname, Float64, vardim)
        var.attrib["_FillValue"] = 1e20
        
        var = ds[varname]
        
        for (k, v) in attrib
            var.attrib[k] = v
        end

        println(var.attrib)

        rng = []
        for i in 1:length(vardim)-1
            push!(rng, Colon())
        end
        push!(rng, 1:size(vardata)[end])
        var[rng...] = vardata

    end

end 
