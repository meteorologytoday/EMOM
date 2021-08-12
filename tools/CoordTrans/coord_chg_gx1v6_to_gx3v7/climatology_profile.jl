using NCDatasets
using Formatting
using SharedArrays

getFn_output = (varname, ens) -> format("xtt_b.e11.B1850C5CN.f09_g16.005.pop.h.{}.{:02d}0001-{:02d}9912.nc", varname, ens, ens)
getFn_input  = (varname, ens) -> format("b.e11.B1850C5CN.f09_g16.005.pop.h.{}.{:02d}0001-{:02d}9912.nc", varname, ens, ens)
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

output_file = getFn_output("AVGSALT_AVGTEMP", 5)

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
