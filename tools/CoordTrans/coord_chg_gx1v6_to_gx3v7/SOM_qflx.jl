using NCDatasets
using Formatting
using SharedArrays

ρ = 1027.0
c_p = 3985.0

getFn = (varname, ens) -> format("b.e11.B1850C5CN.f09_g16.005.pop.h.{}.{:02d}0001-{:02d}9912.nc", varname, ens, ens)
genAttr = function(
    units,
    long_name;
    extra :: Dict = Dict()
)
    d = Dict(
        "units" => units,
        "long_name" => long_name,
    )

    for (k, v) in extra
        d[k] = v
    end

    return d
end

attr2Dict = function(attr)
    d = Dict()
    for k in keys(attr)
        d[k] = attr[k]
    end

    return d
end

output_file = "LENS_B1850C5CN_gx1v6_QFLUX.nc"


days_of_mon = convert(Array{Float64}, [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31])
days_of_year = sum(days_of_mon)

ts = zeros(Float64, 12)

for i = 1:length(ts)
    ts[i] = (i==1) ? 0.0 : ts[i-1] + days_of_mon[i-1]
end



ext_ts = copy(ts)
push!(ext_ts, ts[1] + days_of_year)

Δts = ext_ts[2:end] - ext_ts[1:end-1]
Δts .*= 86400.0

#print(ts)
#print(Δts)

h_ML = 30.0
ds_dom = Dataset("domain.ocn.gx1v6.090206.nc", "r")
Nx = ds_dom.dim["ni"]
Ny = ds_dom.dim["nj"]
mask = ds_dom["mask"][:]

qflx = SharedArray{Float64}(Nx, Ny, 12)
qflx .= 0.0

ens_list = [7, 8, 9, 10]
year_cnt = 0
for ens in ens_list

    println("Doing Ensemble:", ens)

    ds_SHF = Dataset(getFn("SHF", ens), "r")
    ds_SST = Dataset(getFn("SST", ens), "r")

    F   = nomissing(ds_SHF["SHF"][:], NaN)
    SST = view(nomissing(ds_SST["SST"][:], NaN), :, :, 1, :)

    Nt = ds_SHF.dim["time"]

    if Nt % 12 != 0
        throw(ErrorException(format("Time is not multiple of 12. The length I got is {}.", Nt)))
    end

    println("Calculating...")
    @time @sync @distributed for idx in CartesianIndices((1:Nx, 1:Ny))
        i = idx[1]
        j = idx[2]
        for t = 13:Nt-12
            if mask[i, j] == 0
                qflx[i, j, :] .= NaN        
                continue
            end
            
            mon = mod(t-1, 12) + 1

            beg_t = t-1
            end_t = t

            qflx[i, j, mon] += h_ML * ρ * c_p * (SST[i, j, end_t] - SST[i, j, beg_t]) / Δts[mon] - (F[i, j, beg_t] + F[i, j, end_t]) / 2.0
        end
    end
    println("done.")
    close(ds_SHF)
    close(ds_SST)
    
    global year_cnt += (Nt / 12.0)

end

qflx ./= year_cnt

missing_value = 1e20
qflx[isnan.(qflx)] .= missing_value

Dataset(output_file, "c") do ds

    defDim(ds, "Nx", Nx)
    defDim(ds, "Ny", Ny)
    defDim(ds, "time", 12)
    
    defVar(ds, "time", ts, ("time",); attrib=Dict("calendar"=>"noleap", "units"=>"days since 0001-01-01 00:00:00"))

    for varname in ["mask", "area", "xc", "yc", "frac"]
        vardata = ds_dom[varname]
        dims = ("Nx", "Ny")
        v = nomissing(vardata[:], -1)
        v = defVar(ds, varname, v , dims; attrib=attr2Dict(vardata.attrib))
    end 

    
    v = defVar(ds, "qdp", qflx, ("Nx", "Ny", "time");
        fillvalue=missing_value,
        attrib=Dict(
            "long_name" => "Temperature flux convergence in energy",
            "units"     => "W / m^2"
        )
    )
end


close(ds_dom)
