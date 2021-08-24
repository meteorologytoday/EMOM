
using NCDatasets
using ArgParse
using JSON

src = normpath(joinpath(@__DIR__, "..", "..", "..", "src", "models"))

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin

        "--output-file"
            help = "Output file."
            arg_type = String
            required = true
 
        "--data-clim-T-file"
            help = "Climatological temperature data file and its varname separated by comma. Supposed to be 3D."
            arg_type = String
            required = true
 
        "--data-clim-S-file"
            help = "Climatological salinity data file and its varname separated by comma. Supposed to be 3D."
            arg_type = String
            required = true
 
        "--domain-file"
            help = "Domain file, dimension names of lon, lat and varname of mask. Separated by comma. Ex: xxx.nc,ni,nj,mask"
            arg_type = String
            required = true
 
        "--zdomain-file"
            help = "Z coordinate file, varname of zlon. Separated by comma."
            arg_type = String
            required = true
 
        "--topo-file"
            help = "Ocean topology file (depth) and varname of depth. Separated by comma"
            arg_type = String
            required = true

        "--forcing-file"
            help = "Qflux forcing file. Contains varnames: Qflux_T, Qflux_S, MLD."
            arg_type = String
            required = false

        "--T-unit"
            help = "Unit of temperature. Valid string: C, K."
            arg_type = String
            required = true
 
        "--S-unit"
            help = "Unit of salinity. Valid string: PSU, SI"
            arg_type = String
            required = true

        "--relaxation-time"
            help = "Relaxation time of climatology."
            arg_type = Float64


    end

    return parse_args(ARGS, s)
end

parsed = parse_commandline()
print(json(parsed, 4))

if ! (parsed["T-unit"] in ["C", "K"])
    throw(ErrorException("Invalid --T-unit: ", parsed["T-unit"]))
end

if ! (parsed["S-unit"] in ["PSU", "SI"])
    throw(ErrorException("Invalid --S-unit: ", parsed["S-unit"]))
end



println("Processing data...")

Dataset(parsed["domain-file"], "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
#    global mask = convert(Array{Float64}, replace(ds["mask"][:], missing=>NaN))
end

Dataset(parsed["zdomain-file"], "r") do ds
    global zs  = replace(ds["zs"][:], missing=>NaN)
    global Δzs = zs[1:end-1] - zs[2:end]
end

Dataset(parsed["data-clim-T-file"], "r") do ds
    global Ts_clim = replace(ds["TEMP"][:, :, :, 1], missing=>NaN)
end

Dataset(parsed["data-clim-S-file"], "r") do ds
    global Ss_clim = replace(ds["SALT"][:, :, :, 1], missing=>NaN)
end

global Ts_init = Ts_clim
global Ss_init = Ss_clim
global h_ML = zeros(Float64, Nx, Ny) .+ 10.0


Dataset(parsed["topo-file"], "r") do ds
    global topo = zeros(Float64, 1, 1)
    topo = - replace(ds["depth"][:], missing => NaN)
end

#=
if haskey(parsed, "forcing-file")
    if isfile(parsed["forcing-file"]) 
        Dataset(parsed["forcing-file"], "r") do ds
            global h_ML = replace(ds["MLD"][:], missing => NaN)
        end
    else
        println("Cannot find forcing file: ", parsed["forcing-file"],  ". Gonna skip it.")
    end
end
=#

if parsed["T-unit"] == "K"
    Ts_clim .-= 273.15
end

if parsed["S-unit"] == "SI"
    Ss_clim .*= 1000.0
end


