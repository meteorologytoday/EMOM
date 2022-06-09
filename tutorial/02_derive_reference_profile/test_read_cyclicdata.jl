include(joinpath("..", "..", "src", "share", "CyclicData.jl"))
include(joinpath("..", "..", "src", "share", "TimeTools.jl"))

using .CyclicData
using .TimeTools
using CFTime
using NCDatasets
using Dates

vars = Dict(
    "TEMP" => Dict(
        "file" => "output/fivedays_mean/TEMP.nc",
        "idx"  => (1, 233, 184),
    ),

    "VSFC" => Dict(
        "file" => "output/monthly/VSFC.nc",
        "idx"  => (1, 233, 184),
    ),
)


println("Making CyclicDataManager")

beg_time = TimeTools.parseDateTime(DateTimeNoLeap, "0001-01-01 00:00:00")
end_time = TimeTools.parseDateTime(DateTimeNoLeap, "0002-01-01 00:00:00")
align_time = TimeTools.parseDateTime(DateTimeNoLeap, "0001-01-01 00:00:00")

println("beg_time = ", beg_time)
println("end_time = ", end_time)
println("align_time = ", align_time)

data = Dict()

for (varname, varinfo) in vars
    
    println("Interpolating variable: $varname")

    cdm = CyclicDataManager(;
        timetype = DateTimeNoLeap,
        var_file_map = Dict(varname => varinfo["file"]),
        beg_time = beg_time,
        end_time = end_time,
        align_time = align_time,
    )
     
    d = makeDataContainer(cdm)


    dt = Second(86400)
    interp_d = []
    interp_t = []

    _t = DateTimeNoLeap(1, 1, 1)
    for i = 1:365
        interpData!(
            cdm,
            _t,
            d,
        )

        x = d[varname][varinfo["idx"]...]
        if !isfinite(x)
            throw(ErrorException("NaN data."))
        end
        push!(interp_d, x)
        push!(interp_t, _t)

        _t = _t + dt
    end

    data[varname] = Dict(
        "interp_d" => interp_d,
        "interp_t" => interp_t,
        "interp_t_day" => [ timeencode(_t, "days since 0001-01-01 00:00:00", DateTimeNoLeap) for (_, _t) in enumerate(interp_t) ]
    )
end
                


println("Loading PyPlot...")
using PyPlot
plt = PyPlot
println("Done.")

fig, ax = plt.subplots(length(keys(vars)), squeeze = false)

for (i, varname) in enumerate(keys(vars))
    d = data[varname]
    ax[i].plot(d["interp_t_day"], d["interp_d"])
    ax[i].set_title(varname)
end

plt.show()

