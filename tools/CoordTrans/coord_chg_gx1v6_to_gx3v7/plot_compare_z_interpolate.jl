using NCDatasets
using Formatting

fn1 = "clim_LENS_B1850C5CN_005_gx3v7_TEMP.nc"
fn2 = "clim_LENS_B1850C5CN_005_gx3v7_zMLMML_TEMP.nc"
varname = "TEMP"

idx_i = 45   # longitude idx
idx_j = 10   # latitude  idx

Dataset(fn1, "r") do ds

    global Nx = ds.dim["Nx"]
    global Ny = ds.dim["Nx"]
    global Nz_old = ds.dim["Nz"]
    
    global lat = ds["lat"][:]
    global lon = ds["lon"][:]
    global zs_old = (ds["z_w_top"][:] + ds["z_w_bot"][:] ) / 2 / 100.0
    
    global data_old = replace(ds[varname][idx_i, idx_j, :, 1], missing=>NaN)

end

Dataset(fn2, "r") do ds

    global Nz_new = ds.dim["Nz"]
    
    global zs_new = ( ds["zs"][1:end-1] +  ds["zs"][2:end] ) / 2
    
    global data_new = replace(ds[varname][idx_i, idx_j, :, 1], missing=>NaN)

end


print("Loading PyPlot...")
using PyPlot
println("done.")

plt[:figure]()
plt[:plot](zs_old, data_old, "b-",  label="old data")
plt[:plot](zs_new, data_new, "r--", label="new data")
plt[:legend]()

plt[:title](format("(lat, lon) = ({:.2f}, {:.2f})", lat[idx_i, idx_j], lon[idx_i, idx_j]))
plt[:show]()
