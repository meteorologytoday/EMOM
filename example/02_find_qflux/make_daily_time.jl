using ArgParse
using JSON
using DataStructures
using NCDatasets

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

println("""
This file produce an netcdf file with only `time` and `time_bound` variables
for users to append variables to other files. 

Notice: This program uses no-leap calendar (365 days fixed)

""")

s = ArgParseSettings()
@add_arg_table s begin

    "--output"
        help = "The file you want to produce."
        arg_type = String
        required = true

    "--years"
        help = "How many years?"
        arg_type = Int64
        default = 1

end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)


doy = 365

t    = zeros(Float64,    doy)
bnds = zeros(Float64, 2, doy)

for d=1:doy*parsed["years"]
    bnds[1, d] = d-1
    bnds[2, d] = d
    t[d] = (bnds[1, d] + bnds[2, d]) / 2.0
end

Dataset(parsed["output"], "c") do ds

    defDim(ds, "time", Inf)
    defDim(ds, "d2", 2)

    defVar(ds, "time", t, ("time", ), ; attrib = Dict(
        "long_name" => "time",
        "bounds"    => "time_bound",
        "calendar"  =>  "noleap",
        "units"     => "days since 0001-01-01 00:00:00",
    ))

    defVar(ds, "time_bound", bnds, ("d2", "time"), ; attrib = Dict(
        "long_name" => "boundaries for time-averaging interval",
        "units"     => "days since 0001-01-01 00:00:00",
    ))

end
