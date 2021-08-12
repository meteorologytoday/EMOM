include(joinpath(@__DIR__, "..", "CoordTrans", "CoordTrans_ESMF.jl"))

using .CoordTrans_ESMF
using ArgParse
using JSON

function parse_commandline()

    s = ArgParseSettings()
    @add_arg_table s begin

        "--w-file"
            help = "Weighting file."
            arg_type = String
            required = true

        "--s-file"
            help = "Input source file. Filenames separated by commas."
            arg_type = String
            required = true
 
        "--d-file"
            help = "Output destination file."
            arg_type = String
            required = true

        "--vars"
            help = "Variable names list. They should by dimension 2 (x, y) or 3 (x, y, z) with or without record (time) dimension. Ex: --vars=Ts,Ss,MLD"
            arg_type = String

        "--x-dim"
            help = "Variable name of x-dimension."
            arg_type = String
            required = true

        "--y-dim"
            help = "Variable name of y-dimension."
            arg_type = String
            required = true

        "--z-dim"
            help = "Variable name of z-dimension."
            arg_type = String

        "--t-dim"
            help = "Variable name of time-dimension."
            arg_type = String
            default = "time"

        "--s-dir"
            help = "Source files directory. If unset then this variable will not be applied. Convinent when working with multiple files"
            arg_type = String
            default = ""

        "--d-dir"
            help = "Destination files directory. If unset then this variable will not be applied. Convinent when working with multiple files"
            arg_type = String
            default = ""


    end

    return parse_args(ARGS, s)
end

println("Running ", @__FILE__)

parsed = parse_commandline()
print(json(parsed, 4))

if parsed["vars"] != nothing
    varnames=collect(split(parsed["vars"], ","; keepempty=false))
else
    varnames=nothing
end

CoordTrans_ESMF.convertFile(
    parsed["s-file"],
    parsed["d-file"],
    parsed["w-file"],
    varnames=varnames;
    xdim = parsed["x-dim"],
    ydim = parsed["y-dim"],
    zdim = parsed["z-dim"],
    tdim = parsed["t-dim"],
)
