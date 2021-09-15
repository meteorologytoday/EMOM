using Formatting
using NCDatasets
using Statistics

using ArgParse
using JSON

function runOneCmd(cmd)
    println(">> ", string(cmd))
    run(cmd)
end

function pleaseRun(cmd)
    if isa(cmd, Array)
        for i = 1:length(cmd)
            runOneCmd(cmd[i])
        end
    else
        runOneCmd(cmd)
    end
end
ρ    = 1026.0  # kg / m^3
c_p  = 3996.0  # J / kg / K
ρcp = ρ * c_p

input_dir = "hist"
output_dir = "output"

mkpath(output_dir)

Dataset("mixedlayer.nc", "r") do ds
    global h_mean   = mean(nomissing(ds["HBLT"][:, :, 1, :], NaN), dims=3) / 100.0
end

for y=2:3, m=1:12

    time_str = format("{:04d}-{:02d}-01", y, m)
    input_file  = joinpath(input_dir,  "paper2021_POP2_CTL.pop.h.daily.$(time_str).nc")
    output_file = joinpath(output_dir, "qflx.$(time_str).nc")

    println("Doing $(input_file)")  
 
    Dataset(input_file, "r") do ds

        SST      = nomissing(ds["TEMP"][:, :, 1, :], NaN)
        SHF_mean = mean(nomissing(ds["SHF"][:, :, 1, :], NaN), dims=3)
        
        dSSTdt = mean((SST[:, :, 2:end] - SST[:, :, 1:end-1]), dims=3)  / 86400.0
        
        QFLX = ρcp * (dSSTdt .* h_mean) .- SHF_mean

        nlon, nlat, _ = size(h_mean)

        Dataset(output_file, "c") do ds
            
            defDim(ds, "time", Inf)
            defDim(ds, "nlon", nlon)
            defDim(ds, "nlat", nlat)

            for (varname, vardata, varnctype, vardim, attrib) in [
                ("QFLX",    QFLX,   Float64, ("nlon", "nlat", "time"), Dict()),
                ("h_mean",  h_mean, Float64, ("nlon", "nlat", "time"), Dict()),
            ]
                println("Doing varname:", varname)
                var = defVar(ds, varname, varnctype, vardim)
         
                for (k, v) in attrib
                    var.attrib[k] = v
                end

                rng = []
                for i in 1:length(vardim)-1
                    push!(rng, Colon())
                end

                push!(rng, 1:size(vardata)[end])
                var[rng...] = vardata

            end

        end





    end
 

end


