using NCDatasets
using DataStructures
using ArgParse, JSON
using DataStructures

println("""
This program takes in HMXL and any tracer (TEMP or SALT, for example) and 
make sure that the grids within HMXL have the same values as the top grid.
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

        "--file-HMXL"
            help = "The HMXL file (2D). size(HMXL) = (Nx, Ny, Nt)"
            arg_type = String
            required = true

        "--file-TRACER"
            help = "The tracer file (3D). size(TRACER) = (Nx, Ny, Nz, Nt)"
            arg_type = String
            required = true

        "--varname-TRACER"
            help = "The varname of TRACER in tracer file"
            arg_type = String
            required = true

        "--output-file"
            help = "The output file."
            arg_type = String
            required = true
 
        "--output-dimnames"
            help = "The dimnames of output file. Form: (Nx, Ny, Nz)."
            arg_type = String
            nargs = 3
            default = ["Nx", "Ny", "Nz"]
            
    end

    return parse_args(s)
end

parsed = DataStructures.OrderedDict(parse_commandline())
JSON.print(parsed,4)

Dataset(parsed["zdomain-file"], "r") do ds

    global z_w_top, z_w_bot, z_w, Nz

    z_w_top = nomissing(ds["z_w_top"][:], NaN)
    z_w_bot = nomissing(ds["z_w_bot"][:], NaN)

    Nz = length(z_w_top)

    z_w = zeros(Float64, Nz+1)
    z_w[1:end-1] = z_w_top
    z_w[end] = z_w_bot[end]

end

Dataset(parsed["topo-file"], "r") do ds
    global Nz_bot = nomissing(ds["Nz_bot"][:, :], NaN)
    global Nx, Ny = size(Nz_bot)
end

Dataset(parsed["file-HMXL"], "r") do ds
    global HMXL = nomissing(ds["HMXL"][:, :, :], NaN)
end

Dataset(parsed["file-TRACER"], "r") do ds
    global TRACER = nomissing(ds[parsed["varname-TRACER"]][:, :, :, :], NaN)
end

Nt = size(HMXL, 3)

if size(HMXL) != (Nx, Ny, Nt)
    println(size(HMXL))
    throw(ErrorException("Size(HMXL) is not ($Nx, $Ny, $Nt)"))
end

if size(TRACER) != (Nx, Ny, Nz, Nt)
    throw(ErrorException("Size(TRACER) is not ($Nx, $Ny, $Nz, $Nt) "))
end

for t=1:Nt
    println("Doing t=$t")
    for j=1:Ny, i=1:Nx
        _Nz = Nz_bot[i, j]

        if _Nz > 0
            _Nz_HMXL = findlast(z_w_top .>= - HMXL[i, j, t])  # Use ">=" to avoid h = 0 that makes Nz = 0
            TRACER[i, j, 1:_Nz_HMXL, t] .= TRACER[i, j, 1, t] 
        end
    end
end

dim_Nx, dim_Ny, dim_Nz = parsed["output-dimnames"]

Dataset(parsed["output-file"], "c") do ds

    defDim(ds, "time", Inf)
    defDim(ds, dim_Nx, Nx)
    defDim(ds, dim_Ny, Ny)
    defDim(ds, dim_Nz, Nz)

    defVar(ds, parsed["varname-TRACER"], TRACER, (dim_Nx, dim_Ny, dim_Nz, "time"), ; attrib = Dict(
    ))

end
