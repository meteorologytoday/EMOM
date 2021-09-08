using NCDatasets
using Formatting
using ArgParse

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--domain-file"
            help = "Domain file."
            arg_type = String
            required = true
    end

    return parse_args(s)
end

parsed = parse_commandline()


function maketime(years)

    dom = [31.0, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    sum_dom = sum(dom)
    sum_dom == 365 || throw(ErrorException("Sum of dom is $(sum_dom) rather than 365."))

    _t    = zeros(Float64, length(dom))
    _bnds = zeros(Float64, 2, length(dom))

    for m=1:length(dom)
        #bnds[m, 1] = beg of month  m
        #bnds[m, 2] = end of month  m
        if m==1
            _bnds[1, m] = 0.0
        else
            _bnds[1, m] = _bnds[2, m-1]
        end

        _bnds[2, m] = _bnds[1, m] + dom[m]

        _t[m] = (_bnds[1, m] + _bnds[2, m]) / 2.0
    end

    t    = zeros(Float64,    12*years)
    bnds = zeros(Float64, 2, 12*years)


    for y = 1:years
        i_offset = (y-1)*12
        t_offset = (y-1)*sum_dom
        t[i_offset+1:i_offset+12]       .+= _t    .+ t_offset
        bnds[:, i_offset+1:i_offset+12] .+= _bnds .+ t_offset
    end

    return t, bnds
end

Dataset(parsed["domain-file"], "r") do ds

    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    
    global lon = nomissing(ds["xc"][:], NaN) .|> deg2rad
    global lat = nomissing(ds["yc"][:], NaN) .|> deg2rad

end

z_w = collect( Float64, range(0.0, -600.0, length=11) )
Nz = length(z_w)-1

t, bnds = maketime(5)

tt = reshape(t, 1, 1, :)
llat = reshape(lat, size(lat)..., 1)
llon = reshape(lon, size(lon)..., 1)


TAUX  = sin.((tt.-0) / 365.0 * 2π .+ llon) .* cos.(llat) .* sin.(llon       ) * 0.1
TAUY = sin.((tt.-0) / 365.0 * 2π .+ llon) .* cos.(llat) .* sin.(llon + llat) * 0.1
SWFLX      = (1.0 .+ sin.((tt.-0) / 365.0 * 2π .+ llon * 2))/2.0 .* cos.(llat) * (-1000.0) 
NSWFLX     = (1.0 .+ cos.((tt.-0) / 365.0 * 2π .+ llon * 2))/2.0 .* cos.(llat) * (  500.0) 
VSFLX      = (1.0 .+ cos.((tt.-0) / 365.0 * 2π .+ llon * 2))/2.0 .* cos.(llat) * ( 1.0 / 86400.0 ) 


println("Outputting atmospheric forcing.nc")
Dataset("atm_forcing.nc", "c") do ds

    defDim(ds, "time", Inf)
    defDim(ds, "d2", 2)
    defDim(ds, "nlon", Nx)
    defDim(ds, "nlat", Ny)

    defVar(ds, "time", t, ("time", ), ; attrib = Dict(
        "long_name" => "time",
        "bounds"    => "time_bound",
        "calendar"  =>  "noleap",
        "units"     => "days since 0001-01-01 00:00:00",
    ))

    defVar(ds, "time_bound", bnds, ("d2", "time"), ; attrib = Dict(
        "long_name" => "boundaries for time-averaging interval",
        "units"     => "days since 0001-01-01 00:00:00",
    ))


    defVar(ds, "TAUX", TAUX, ("nlon", "nlat", "time",), ; attrib = Dict(
        "long_name" => "TAUX east",
        "units"     => "N/m^2",
    ))

    defVar(ds, "TAUY", TAUY, ("nlon", "nlat", "time", ), ; attrib = Dict(
        "long_name" => "TAUY north",
        "units"     => "N/m^2",
    ))


    defVar(ds, "SWFLX", SWFLX, ("nlon", "nlat", "time", ), ; attrib = Dict(
        "long_name" => "SWFLX",
        "units"     => "W/m^2",
    ))


    defVar(ds, "NSWFLX", NSWFLX, ("nlon", "nlat", "time", ), ; attrib = Dict(
        "long_name" => "NSWFLX",
        "units"     => "W/m^2",
    ))
    
    defVar(ds, "VSFLX", VSFLX, ("nlon", "nlat", "time", ), ; attrib = Dict(
        "long_name" => "VSFLX",
        "units"     => "kg/s/m^2",
    ))

    defVar(ds, "z_w_top", z_w[1:end-1], ("z_t", ), ; attrib = Dict(
        "long_name" => "Z coordinate at grid top.",
        "units"     => "m",
    ))

end



t, bnds = maketime(1)

tt = reshape(t, 1, 1, :)
llat = reshape(lat, size(lat)..., 1)
llon = reshape(lon, size(lon)..., 1)

z_w = collect( Float64, range(0.0, -300.0, length=11) )
z_t = (z_w[1:end-1] + z_w[2:end])/2.0
Nz = length(z_w)-1

HMXL = (1.0 .+ sin.((tt.-0) / 365.0 * 2π .+ llon * 2))/2.0 .* cos.(llat) * 100 .+ 30.0 

tt = reshape(t, 1, 1, 1, :)
llat = reshape(lat, size(lat)..., 1, 1)
llon = reshape(lon, size(lon)..., 1, 1)
zz_t = reshape(z_t, 1, 1, :, 1)

TEMP  = exp.(zz_t / 50.0) .* (1.0 .+ sin.((tt.-0) / 365.0 * 2π .+ llon * 2))/2.0 .* cos.(llat) * 30.0 
SALT  = exp.(zz_t / 50.0) .* (1.0 .+ sin.((tt.-0) / 365.0 * 2π .+ llon * 2))/2.0 .* cos.(llat) * 30.0 

QFLX_TEMP  = exp.(zz_t / 50.0) .* cos.((tt.-0) / 365.0 * 2π .+ llon * 2) .* cos.(llat) * 1e-6 * 3996 * 1026 
QFLX_SALT  = exp.(zz_t / 50.0) .* sin.((tt.-0) / 365.0 * 2π .+ llon * 2) .* cos.(llat) * 1e-6 


println("Outputting ocean forcing.")
Dataset("ocn_forcing.nc", "c") do ds

    defDim(ds, "time", Inf)
    defDim(ds, "d2", 2)
    defDim(ds, "nlon", Nx)
    defDim(ds, "nlat", Ny)
    defDim(ds, "z_t", Nz)

    defVar(ds, "time", t, ("time", ), ; attrib = Dict(
        "long_name" => "time",
        "bounds"    => "time_bound",
        "calendar"  =>  "noleap",
        "units"     => "days since 0001-01-01 00:00:00",
    ))

    defVar(ds, "time_bound", bnds, ("d2", "time"), ; attrib = Dict(
        "long_name" => "boundaries for time-averaging interval",
        "units"     => "days since 0001-01-01 00:00:00",
    ))


    defVar(ds, "TEMP", TEMP, ("nlon", "nlat", "z_t", "time",), ; attrib = Dict(
        "long_name" => "TEMP",
        "units"     => "degC",
    ))

    defVar(ds, "SALT", SALT, ("nlon", "nlat", "z_t", "time",), ; attrib = Dict(
        "long_name" => "SALT",
        "units"     => "kg/m^3",
    ))


    defVar(ds, "QFLX_TEMP", QFLX_TEMP, ("nlon", "nlat", "z_t", "time", ), ; attrib = Dict(
        "long_name" => "QFLX_TEMP",
        "units"     => "W/m^3",
    ))

    defVar(ds, "QFLX_SALT", QFLX_SALT, ("nlon", "nlat", "z_t", "time", ), ; attrib = Dict(
        "long_name" => "QFLX_SALT",
        "units"     => "kg/m^3/s/m^3",
    ))

    defVar(ds, "HMXL", HMXL, ("nlon", "nlat", "time", ), ; attrib = Dict(
        "long_name" => "HMXL",
        "units"     => "m",
    ))

    defVar(ds, "z_w_top", z_w[1:end-1], ("z_t", ), ; attrib = Dict(
        "long_name" => "Z coordinate at grid top.",
        "units"     => "m",
    ))

    defVar(ds, "z_w_bot", z_w[2:end], ("z_t", ), ; attrib = Dict(
        "long_name" => "Z coordinate at grid bottom.",
        "units"     => "m",
    ))

end



