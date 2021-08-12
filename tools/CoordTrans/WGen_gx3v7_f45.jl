include("CoordTrans.jl")

using .CoordTrans

using NCDatasets
using Distributed
using SharedArrays
using Formatting

s_map_file = "domain.ocn.gx3v7.120323.nc"
d_map_file = "domain.lnd.fv4x5_gx3v7.091218.nc"
wgt_file = "wgt_gx3v7_to_fv4x5.nc"

const NNN_max = 9
const missing_value = 1e20

Dataset(s_map_file, "r") do ds
        global s_mask, s_Nx, s_Ny, s_N, s_lat, s_lon

        s_mask = replace(reshape(ds["mask"][:], :), missing=>NaN)
        s_Nx = ds.dim["ni"]
        s_Ny = ds.dim["nj"]
        s_N  = s_Nx * s_Ny
        s_lon = replace(reshape(ds["xc"][:], :), missing=>NaN)
        s_lat = replace(reshape(ds["yc"][:], :), missing=>NaN)

        global gi_s = CoordTrans.GridInfo(
            gc_lon = s_lon,
            gc_lat = s_lat,
            area   = copy(s_lon),
            mask   = s_mask,
            unit_of_angle = :deg,
            dims = [s_Nx, s_Ny],
        )

end

Dataset(d_map_file, "r") do ds
        global d_mask, d_Nx, d_Ny, d_N, d_lat, d_lon

        d_mask = 1 .- replace(reshape(ds["mask"][:], :), missing=>NaN)
        d_Nx = ds.dim["ni"]
        d_Ny = ds.dim["nj"]
        d_N = d_Nx * d_Ny
        d_lon = replace(reshape(ds["xc"][:], :), missing=>NaN)
        d_lat = replace(reshape(ds["yc"][:], :), missing=>NaN)

        global gi_d = CoordTrans.GridInfo(
            gc_lon = d_lon,
            gc_lat = d_lat,
            area   = copy(d_lon),
            mask   = d_mask,
            unit_of_angle = :deg,
            dims = [d_Nx, d_Ny],
        )
end

CoordTrans.genWeight_NearestNeighbors(wgt_file, gi_s, gi_d, NNN_max)

