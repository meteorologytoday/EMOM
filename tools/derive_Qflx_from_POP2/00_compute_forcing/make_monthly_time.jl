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


dom = [31.0, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
sum_dom = sum(dom)
sum_dom == 365 || throw(ErrorException("Sum of dom is $(sum_dom) rather than 365."))

_t    = zeros(Float64, length(dom))
_bnds = zeros(Float64, 2, length(dom))

for m=1:length(dom)
    #bnds[m, 1] = beg of month  m
    #bnds[m, 2] = end of month  m
    if m==1
        _bnds[1, m] = 0.0
    else
        _bnds[1, m] = _bnds[2, m-1]
    end

    _bnds[2, m] = _bnds[1, m] + dom[m]

    _t[m] = (_bnds[1, m] + _bnds[2, m]) / 2.0
end

t    = zeros(Float64, 12*parsed["years"])
bnds = zeros(Float64, 2, 12*parsed["years"])


for y = 1:parsed["years"]
    i_offset = (y-1)*12
    t_offset = (y-1)*sum_dom
    t[i_offset+1:i_offset+12]       .+= _t    .+ t_offset
    bnds[:, i_offset+1:i_offset+12] .+= _bnds .+ t_offset
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
