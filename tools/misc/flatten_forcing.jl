using NCDatasets
using DataStructures
using ArgParse, JSON
using DataStructures

println("""
This program adjust the forcing file such that HMXL and TEMP/SALT are conform.
That is, if HMXL occupies n grids, then TEMP/SALT in top n grids will be set
to the top grid value.
""")

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


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--zdomain-file"
            help = "Vertical domain file containing z_w_top, z_w_bot in meters with z=0 is the surface."
            arg_type = String
            required = true

        "--topo-file"
            help = "File containing Nz_bot."
            arg_type = String
            required = true

        "--forcing-file"
            help = "Forcing file that contains HMXL, SALT and TEMP"
            arg_type = String
            required = true

        "--output-file"
            help = "The output file."
            arg_type = String
            required = true
 
    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
JSON.print(parsed,4)


pleaseRun(`julia $(@__DIR__)/flatten_surface.jl
    --zdomain-file $(parsed["zdomain-file"]) 
    --topo-file $(parsed["topo-file"])
    --file-HMXL $(parsed["forcing-file"])
    --file-TRACER $(parsed["forcing-file"])
    --varname-TRACER TEMP
    --output-file "_tmp_flattened_TEMP.nc"
    --output-dimnames nlon nlat z_t
`)

pleaseRun(`cp $(parsed["forcing-file"]) $(parsed["output-file"])`)
pleaseRun(`ncks -A -v TEMP _tmp_flattened_TEMP.nc $(parsed["output-file"])`)
