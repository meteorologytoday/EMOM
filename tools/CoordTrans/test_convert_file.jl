include("WeightGeneration.jl")

using .WeightGeneration

using Formatting

in_filename  = "b.e11.B1850C5CN.f09_g16.005.pop.h.SST.100001-109912.nc"
out_filename = "test_SST.nc"
wgt_filename = "wgt_gx1v6_to_gx3v7.nc"

#=
WeightGeneration.convertFile(
    in_filename,
    out_filename,
    wgt_filename,
    varnames=("SHF",);
    xdim = "nlon",
    ydim = "nlat",
    zdim = "z_w",
)
=#
WeightGeneration.convertFile(
    in_filename,
    out_filename,
    wgt_filename,
    varnames=("SST",);
    xdim = "nlon",
    ydim = "nlat",
    zdim = "z_t",
)
