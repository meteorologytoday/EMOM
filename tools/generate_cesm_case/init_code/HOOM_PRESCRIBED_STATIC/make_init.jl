include(joinpath("..", "load_files.jl"))
include(joinpath(src, "NKOM", "NKOM.jl"))
using .NKOM

ocn = NKOM.Ocean(
    gridinfo_file = parsed["domain-file"],
    Nx       = Nx,
    Ny       = Ny,
    zs_bone  = zs,
    Ts       = Ts_init,
    Ss       = Ss_init,
    T_ML     = Ts_clim[:, :, 1],
    S_ML     = Ss_clim[:, :, 1],
    h_ML     = h_ML[:, :, 1],
    h_ML_min = 10.0,
    h_ML_max = 1e5,             # make it unrestricted
    mask     = mask,
    topo     = topo,
    Ts_clim_relax_time = parsed["relaxation-time"],
    Ts_clim            = copy(Ts_clim),
    Ss_clim_relax_time = parsed["relaxation-time"],
    Ss_clim            = copy(Ss_clim),
    arrange  = :xyz,
    do_convective_adjustment = true,
)

NKOM.takeSnapshot(ocn, parsed["output-file"])

