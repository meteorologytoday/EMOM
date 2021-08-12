include(joinpath(@__DIR__, "..", "CoordTrans", "CoordTrans.jl"))
include(joinpath(@__DIR__, "..", "CoordTrans", "CoordTrans_ESMF.jl"))

using .CoordTrans
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
            help = "Output destination file. Filenames separated by commas."
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

        "--t-len"
            help = "If this is not -1 then time will be a non-record dimension with length specified here."
            arg_type = Int64
            default = -1



        "--s-dir"
            help = "Source files directory. If unset then this variable will not be applied. Convinent when working with multiple files"
            arg_type = String
            default = ""

        "--d-dir"
            help = "Destination files directory. If unset then this variable will not be applied. Convinent when working with multiple files"
            arg_type = String
            default = ""

        "--algo"
            help = "Type of algorithm. Valid values: `XTT`, `ESMF`."
            arg_type = String
            default = "ESMF"

    end

    return parse_args(ARGS, s)
end

println("Running ", @__FILE__)

parsed = parse_commandline()
print(json(parsed, 4))

if parsed["vars"] != nothing
    varnames = collect(split(parsed["vars"], ","; keepempty=false))
else
    varnames = nothing
end

s_files = collect(split(parsed["s-file"], ","; keepempty=false))
d_files = collect(split(parsed["d-file"], ","; keepempty=false))

if length(s_files) != length(d_files)
    throw(ErrorException("Numbers of source files and destination files do not match."))

end


if parsed["algo"] == "XTT"
    wi = CoordTrans.readWeightInfo(parsed["w-file"])
elseif parsed["algo"] == "ESMF"
    wi = CoordTrans_ESMF.readWeightInfo(parsed["w-file"])
end

for i in 1:length(s_files)

    s_file = ( parsed["s-dir"] == "" ) ? s_files[i] : joinpath(parsed["s-dir"], s_files[i])
    d_file = ( parsed["d-dir"] == "" ) ? d_files[i] : joinpath(parsed["d-dir"], d_files[i])
    println("Trasform: ", s_file, " => ", d_file)

    if parsed["algo"] == "XTT"

        println("### Algo: XTT ###")
        CoordTrans.convertFile(
            s_file,
            d_file,
            wi,
            varnames=varnames;
            xdim = parsed["x-dim"],
            ydim = parsed["y-dim"],
            zdim = parsed["z-dim"],
            tdim = parsed["t-dim"],
            tlen = parsed["t-len"]
        )

    elseif parsed["algo"] == "ESMF"
        println("### Algo: ESMF ###")

        CoordTrans_ESMF.convertFile(
            s_file,
            d_file,
            wi,
            varnames=varnames;
            xdim = parsed["x-dim"],
            ydim = parsed["y-dim"],
            zdim = parsed["z-dim"],
            tdim = parsed["t-dim"],
            tlen = parsed["t-len"]
        )

    end
end
