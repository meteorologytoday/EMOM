include(joinpath("..", "load_files.jl"))
include(joinpath(src, "NKOM", "NKOM.jl"))
using .NKOM


zs = zeros(Float64, 2)

zs[1] = 0.0
zs[2] = minimum(topo[isfinite.(topo)])

Ts_clim = reshape(Ts_clim[:, :, 1], Nx, Ny, 1)
Ss_clim = reshape(Ss_clim[:, :, 1], Nx, Ny, 1)

h_ML = zeros(Nx, Ny)
h_ML .= 1.0


ocn = NKOM.Ocean(
    gridinfo_file = parsed["domain-file"],
    Nx       = Nx,
    Ny       = Ny,
    zs_bone  = zs,
    Ts       = Ts_clim,
    Ss       = Ss_clim,
    T_ML     = Ts_clim[:, :, 1],
    S_ML     = Ss_clim[:, :, 1],
    h_ML     = h_ML, 
    h_ML_min = 1e-3,                 # cannot be 0 
    h_ML_max = -zs[end],             # make it unrestricted
    mask     = mask,
    topo     = topo,
    Ts_clim_relax_time = 0.0,
    Ts_clim            = nothing,
    Ss_clim_relax_time = 0.0,
    Ss_clim            = nothing,
    arrange  = :xyz,
)

NKOM.takeSnapshot(ocn, parsed["output-file"])
