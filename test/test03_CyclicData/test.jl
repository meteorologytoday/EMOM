include("IOM/src/share/CyclicData.jl")

using .CyclicData
using CFTime
using NCDatasets
using Dates

test_file = "test.nc"
println("Making test data $(test_file)")

period = 2*365
t = (range(0, period, length=51) |> collect)[1:end-1]
t0 = 0.0
v = cos.( (t .- t0) / 365.0 * 2π) + t * 0.001

# v is of shape (x, y, time)
v = reshape(v, 1, 1, :)

Dataset(test_file, "c") do ds

    defDim(ds, "Nx", 1)
    defDim(ds, "Ny", 1)
    defDim(ds, "time", Inf)

    for (varname, vardata, vardim, attrib) in [
        ("v",     v, ("Nx", "Ny", "time",), Dict()),
        ("time",  t, ("time",), Dict(
            "calendar" => "noleap",
            "units"    => "days since 0000-01-01 00:00:00",
        )),
    ]
        println("Doing varname:", varname)
        var = defVar(ds, varname, Float64, vardim)
        var.attrib["_FillValue"] = 1e20
        
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


println("Making CyclicDataManager")
_t = DateTimeNoLeap(3,1, 1)
cdm = CyclicDataManager(;
    timetype = DateTimeNoLeap,
    var_file_map = Dict("v" => test_file),
    beg_time = DateTimeNoLeap(0, 1, 1),
    end_time = DateTimeNoLeap(2, 1, 1),
    align_time = _t,
)
 
d = makeDataContainer(cdm)

println("Interpolating data")
dt = Second(86400)
interp_d = []
interp_t = []

for i = 1:365*5

    global _t 

    interpData!(
        cdm,
        _t,
        d,
    )

    push!(interp_d, d["v"][1,1])
    push!(interp_t, _t)

    _t = _t + dt
end
            
interp_t_day = [ timeencode(_t, "days since 0001-01-01 00:00:00", DateTimeNoLeap) for (_, _t) in enumerate(interp_t) ]

println("Plotting")

using PyPlot
plt = PyPlot

plt.plot(interp_t_day, interp_d)
plt.scatter(t, v, s=20, marker="o")

for i=1:5
    plt.scatter(t .+ period*(i-1), v, s=2, marker="o", color="black")
end

plt.show()


