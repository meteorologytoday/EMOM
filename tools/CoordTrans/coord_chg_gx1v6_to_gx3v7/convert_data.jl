using NCDatasets
using Distributed
using SharedArrays
using Formatting

s_file  = ARGS[1]
d_file  = ARGS[2]
varname = ARGS[3]

wgt_file = "wgt_gx1v6_to_gx3v7.nc"

ds_w = Dataset(wgt_file, "r")
ds_s = Dataset(s_file, "r")
ds_d = Dataset(d_file, "c")

missing_value = 1e20


NN_idx = convert(Array{Integer}, nomissing(ds_w["NN_idx"][:], 0))
NNN = size(NN_idx)[1]

d_Nx = ds_w.dim["d_Nx"]
d_Ny = ds_w.dim["d_Ny"]
d_N = d_Nx * d_Ny

defDim(ds_d, "Nx", d_Nx)
defDim(ds_d, "Ny", d_Ny)
defDim(ds_d, "time", Inf)

d_var = defVar(ds_d, varname, Float64, ("Nx", "Ny"))
d_var.attrib["_FillValue"] = missing_value

# Write grid information
for (varname, vardata, dims) in (
    ("lat", ds_w["d_lat"][:], ("Nx", "Ny")),
    ("lon", ds_w["d_lon"][:], ("Nx", "Ny")),
)
    v = defVar(ds_d, varname, Float64, dims)
    v.attrib["_FillValue"] = missing_value
    v[:] = vardata
end

println("NNN: ", NNN)

d_data = zeros(Float64, d_Nx, d_Ny)

###############

d_data .= 0.0
s_data = reshape(nomissing(ds_s[varname][:, :], NaN), :)

for i = 1 : length(d_data)
    if NN_idx[1, i] == 0
        d_data[i] = missing_value
        continue
    end

    for j = 1:NNN
        d_data[i] += s_data[NN_idx[j, i]]
    end
    d_data[i] /= NNN
end

d_var[:, :] = d_data

##############
#=

for t = 1 : ds_s.dim["time"]
    global d_data
    print("\rProcessing time: ", t)
    d_data .= 0.0
    s_data = reshape(nomissing(ds_s[varname][:, :, t], NaN), :)
    
    for i = 1 : length(d_data)
        if NN_idx[1, i] == 0
            d_data[i] = missing_value
            continue
        end

        for j = 1:NNN
            d_data[i] += s_data[NN_idx[j, i]]
        end
        d_data[i] /= NNN
    end

    d_var[:, :, t] = d_data
end

=#

println("done.")

close(ds_w)
close(ds_s)
close(ds_d)



