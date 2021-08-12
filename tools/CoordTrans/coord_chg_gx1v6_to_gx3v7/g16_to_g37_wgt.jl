using NCDatasets
using Distributed
using SharedArrays
using Formatting

s_map_file = "b.e11.B1850C5CN.f09_g16.005.pop.h.SST.100001-109912.nc"
d_map_file = "domain.ocn.gx3v7.120323.nc"

wgt_file = "wgt_gx1v6_to_gx3v7.nc"

const NNN = 9
missing_value = 1e20

Dataset(s_map_file, "r") do ds
        global s_mask, s_Nx, s_Ny, s_N, s_lat, s_lon

        s_mask = reshape(ds["REGION_MASK"][:], :)
        s_Nx = ds.dim["nlon"]
        s_Ny = ds.dim["nlat"]
        s_N  = s_Nx * s_Ny
        s_lon = reshape(ds["TLONG"][:] .|> deg2rad, :)
        s_lat = reshape(ds["TLAT"][:] .|> deg2rad, :)
end

Dataset(d_map_file, "r") do ds
        global d_mask, d_Nx, d_Ny, d_N, d_lat, d_lon

        d_mask = reshape(ds["mask"][:], :)
        d_Nx = ds.dim["ni"]
        d_Ny = ds.dim["nj"]
        d_N = d_Nx * d_Ny
        d_lon = reshape(ds["xc"][:] .|> deg2rad, :)
        d_lat = reshape(ds["yc"][:] .|> deg2rad, :)
end


#trans = spzeros(Float64, d_N, s_N)
trans = SharedArray{Float64}(NNN, d_N)

# s_coord and d_coord are the coordinates of grid points
# in 3-dimensional cartesian coordinate

s_coord = zeros(Float64, s_N, 3)
d_coord = zeros(Float64, d_N, 3)

s_coord[:, 1] .= cos.(s_lat) .* cos.(s_lon)
s_coord[:, 2] .= cos.(s_lat) .* sin.(s_lon)
s_coord[:, 3] .= sin.(s_lat)

d_coord[:, 1] .= cos.(d_lat) .* cos.(d_lon)
d_coord[:, 2] .= cos.(d_lat) .* sin.(d_lon)
d_coord[:, 3] .= sin.(d_lat)

s_NaN_idx = (s_mask .== 0)

println("Start making transform matrix... ")
#idx_arr = zeros(Integer, s_N)
#dist2   = zeros(Float64, s_N)

@time @sync @distributed for i = 1:d_N

    # For every point find its nearest-neighbors

    print("\r", i, "/", d_N)

    if d_mask[i] == 0
        trans[:, i] .= missing_value
        continue
    end


    dist2 = (  (s_coord[:, 1] .- d_coord[i, 1]).^2
             + (s_coord[:, 2] .- d_coord[i, 2]).^2
             + (s_coord[:, 3] .- d_coord[i, 3]).^2 )


    # Decided not to apply this condition because in 
    # extreme cases there might be a small area of water
    # that is surrounded by lands.

    dist2[s_NaN_idx] .= NaN
 
    idx_arr = 1:s_N |> collect
    sort!(idx_arr; by=(k)->dist2[k])
    trans[:, i] = idx_arr[1:NNN]

end
println("done.")


s_lat = reshape(s_lat, s_Nx, :)
s_lon = reshape(s_lon, s_Nx, :)
d_lat = reshape(d_lat, d_Nx, :)
d_lon = reshape(d_lon, d_Nx, :)

Dataset(wgt_file, "c") do ds

    defDim(ds, "s_Nx", s_Nx)
    defDim(ds, "s_Ny", s_Ny)
    defDim(ds, "s_N",  s_N)

    defDim(ds, "d_Nx", d_Nx)
    defDim(ds, "d_Ny", d_Ny)
    defDim(ds, "d_N",  d_N)
    
    defDim(ds, "NNN", NNN)


    for (varname, vardata, dims) in (
        ("NN_idx", trans, ("NNN", "d_N")),
        ("s_lat", s_lat, ("s_Nx", "s_Ny")),
        ("s_lon", s_lon, ("s_Nx", "s_Ny")),
        ("d_lat", d_lat, ("d_Nx", "d_Ny")),
        ("d_lon", d_lon, ("d_Nx", "d_Ny")),
    )

        print(format("Output data: {} ...", varname))
        v = defVar(ds, varname, Float64, dims)
        v.attrib["_FillValue"] = missing_value
        v[:] = vardata
        println("done.")
    end
    
end



