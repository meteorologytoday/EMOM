using NCDatasets

using ArgParse, JSON
function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config-file"
            help = "Casename"
            arg_type = String
            required = true

        "--project-code"
            help = "Project code for PBS -A option"
            arg_type = String
            default = ""

        "--ncpu"
            help = "MPI cpus used"
            arg_type = Int64
            default = 36


        "--walltime"
            help = "Walltime for PBS -l walltime option"
            arg_type = String
            default = "06:00:00"

    end

    return parse_args(s)
end

parsed = parse_commandline()

JSON.print(parsed,4)

using TOML
config = TOML.parsefile(parsed["config-file"])

caseroot = config["DRIVER"]["caseroot"]

runfile = joinpath(caseroot, "run.$(config["DRIVER"]["casename"]).sh")
open(runfile, "w") do io
    write(io, """
#!/bin/bash
#PBS -A $(parsed["project-code"])
#PBS -N $(config["DRIVER"]["casename"])
#PBS -q economy
#PBS -l select=1:ncpus=36:mpiprocs=36:ompthreads=1
#PBS -l walltime=$(parsed["walltime"])
#PBS -j oe
#PBS -S /bin/bash

mpiexec -n $(parsed["ncpu"]) julia --project   \\
    $(@__DIR__)/main.jl          \\
        --stop-n=2               \\
        --time-unit=year         \\
        --config-file=$(caseroot)/config.toml \\
        --atm-forcing-file=$(@__DIR__)/data/POP2PROFILE.g16.nc
        
    """)
end

chmod(runfile, 0o750)
