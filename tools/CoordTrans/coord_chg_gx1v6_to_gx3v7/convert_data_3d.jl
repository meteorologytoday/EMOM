using NCDatasets
using Distributed
using SharedArrays
using Formatting



const jobs    = Channel{Tuple}(32)
const results = Channel{Tuple}(32)

var = ARGS[1]
ens = parse(Int, ARGS[2])

varname = var
s_map_file = format("clim_b.e11.B1850C5CN.f09_g16.{:03d}.pop.h.{}.050001-059912.nc", ens, varname)
wgt_file = "wgt_gx1v6_to_gx3v7.nc"
d_file = format("clim_LENS_B1850C5CN_{:03d}_gx3v7_{}.nc", ens, varname)

ds_w = Dataset(wgt_file, "r")
ds_s = Dataset(s_map_file, "r")
ds_d = Dataset(d_file, "c")

missing_value = 1e20

NN_idx = convert(Array{Integer}, nomissing(ds_w["NN_idx"][:], 0))
NNN = size(NN_idx)[1]

d_Nt = ds_s.dim["time"]
d_Nx = ds_w.dim["d_Nx"]
d_Ny = ds_w.dim["d_Ny"]
d_Nz = ds_s.dim["z_t"]

d_N = d_Nx * d_Ny

defDim(ds_d, "Nx", d_Nx)
defDim(ds_d, "Ny", d_Ny)
defDim(ds_d, "Nz", d_Nz)
defDim(ds_d, "time", Inf)

# Write horizontal grid information
for (varname, vardata, dims) in (
    ("lat", ds_w["d_lat"][:], ("Nx", "Ny",)),
    ("lon", ds_w["d_lon"][:], ("Nx", "Ny",)),
    ("z_w_top", ds_s["z_w_top"][:], ("Nz",)),
    ("z_w_bot", ds_s["z_w_bot"][:], ("Nz",)),
)
    println("varname: ", varname)
    v = defVar(ds_d, varname, Float64, dims)
    v.attrib["_FillValue"] = missing_value
    v[:] = vardata
end


println("NNN: ", NNN)

# ===== [BEGIN] parallel computation code =====

jobs_total = d_Nt * d_Nz
jobs_left  = jobs_total

function make_jobs()

    for k = 1:d_Nz, t = 1:d_Nt
        put!(jobs, (k, t))
    end

end

function do_work()
  
    #println("This is my pid: ", myid()) 
    for (k, t) in jobs
        d_data = zeros(Float64, d_Nx, d_Ny) # do it layer by layer
        s_data = reshape(nomissing(ds_s[varname][:, :, k, t], NaN), :)
        
        for i = 1 : length(d_data)
            if NN_idx[1, i] == 0
                d_data[i] = missing_value
                continue
            end

            members = 0.0
            for j = 1:NNN
                if isfinite(NN_idx[j, i])
                    d_data[i] += s_data[NN_idx[j, i]]
                    members += 1.0
                end
            end

            if members == 0.0
                println("Warning: no valid points to interpolate this ocean grid. Index: (", mod(i, d_Nx), ", ", floor(i/d_Nx), ")")
            end

            d_data[i] /= members

        end
        put!(results, (k, t, d_data))
    end
end

# ===== [END] parallel computation code =====

println("Workers: ", workers())

@async make_jobs()

for p in workers()
    @async do_work()
end



d_var = defVar(ds_d, varname, Float64, ("Nx", "Ny", "Nz", "time"))
d_var.attrib["_FillValue"] = missing_value

@elapsed while jobs_left > 0
    
    completed_jobs = jobs_total - jobs_left

    print(format("\rProgress: {:.2f}% ({:d} / {:d})",  completed_jobs / jobs_total * 100.0, completed_jobs, d_Nt))


    k, t, d_data = take!(results)

    d_var[:, :, k, t] = d_data
     
    global jobs_left -= 1

    if jobs_left == 0
        println()
    end
end


final_data = nomissing(d_var[:], NaN)

println("Total data count: ", length(final_data))
println("Total valid data count: ", sum(isfinite.(final_data)))
println("Total data holes count: ", sum(isnan.(final_data)))

close(ds_w)
close(ds_s)
close(ds_d)


println("Program ends.")
