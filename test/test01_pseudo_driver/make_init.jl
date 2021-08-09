include(normpath(joinpath(@__DIR__, "HOOM", "src", "models", "HOOM", "HOOM.jl")))

using NCDatasets

println("Processing data...")


domain_file = "domain.ocn_aqua.fv4x5_gx3v7.091218.nc"
zdomain_file = ""
topo_file = ""
output_file = "ocn_init.nc"
Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = convert(Array{Float64}, replace(ds["mask"][:], missing=>NaN))
end

mask .= 1.0
mask[:, 1]   .= 0.0
mask[:, end] .= 0.0

if zdomain_file != ""
    Dataset(zdomain_file, "r") do ds
        global zs  = replace(ds["zs"][:], missing=>NaN)
    end
else
    zs = collect(Float64, 0:-50:-1000)
end

if topo_file != ""
    Dataset(topo_file, "r") do ds
        global topo  = - replace(ds["depth"][:], missing=>NaN)
    end
else
    global topo = nothing
end




ocn = HOOM.Ocean(
    gridinfo_file = domain_file,
    Nx       = Nx,
    Ny       = Ny,
    zs_bone  = zs,
    Ts       = 15.0,
    Ss       = 35.0,
    T_ML     = 15.0,
    S_ML     = 35.0,
    h_ML     = 10.0, 
    h_ML_min = 10.0,
    h_ML_max = 1e5,             # make it unrestricted
    topo     = topo,
    Ts_clim_relax_time = 86400.0 * 10,
    Ts_clim            = nothing, #Ts_clim,
    Ss_clim_relax_time = 86400.0 * 10,
    Ss_clim            = nothing, #Ss_clim,
    arrange  = :xyz,
    do_convective_adjustment = true,
)

HOOM.takeSnapshot(ocn, output_file)


