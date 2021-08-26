using ArgParse
using Formatting
using JSON
using DataStructures

function pleaseRun(cmd)
    println(">> ", string(cmd))
    run(cmd)
end

function getOneEntryFromXML(filename, id)
    return readchomp(`./xmlquery $(id) -silent -valonly`)
end

function getXML(filename, ids)
    println("Reading XML file $(filename)")
    d = OrderedDict()
    for id in ids
        d[id] = getOneEntryFromXML(filename, id)
    end
    return d
end


s = ArgParseSettings()
@add_arg_table s begin

    "--ncpu"
        help = "The number of CPUs that IOM can use"
        arg_type = Int64
        required = true


    "--root"
        help = "The folder where case folders are contained"
        arg_type = String
        required = true

    "--project"
        help = "Project code sent to PBS scheduling system"
        arg_type = String
        required = true

    "--walltime"
        help = "Walltime sent to PBS scheduling system"
        arg_type = String
        required = true

    "--queue"
        help = "Queue sent to PBS scheduling system"
        arg_type = String
        default = "economy"


    "--casename"
        help = "Casename"
        arg_type = String
        required = true

    "--resolution"
        help = "Casename"
        arg_type = String
        required = true

    "--compset"
        help = "Casename"
        arg_type = String
        required = true

    "--machine"
        help = "Casename"
        arg_type = String
        required = true

    "--cesm-root"
        help = "Casename"
        arg_type = String
        required = true

    "--user-namelist-dir"
        help = "Casename"
        arg_type = String
        default = ""

    "--env-run"
        help = "The json file used to set env.xml"
        arg_type = String
        default = ""

    "--env-mach-pes"
        help = "The json file used to set env_mach_pes.xml"
        arg_type = String
        default = ""


end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

if parsed["env-run"] != ""
    overwrite_env_run = JSON.parsefile(parsed["env-run"], dicttype=DataStructures.OrderedDict)

    println("Loaded env-run file ", parsed["env-run"])
    JSON.print(overwrite_env_run, 4)
end

if parsed["env-mach-pes"] != ""
    overwrite_env_mach_pes = JSON.parsefile(parsed["env-run"], dicttype=DataStructures.OrderedDict)
    println("Loaded env-run file ", parsed["env-mach-pes"])
    JSON.print(overwrite_env_mach_pes, 4)
end

env_run_vars = [
    "CASEROOT",
    "RUNDIR",
    "DIN_LOC_ROOT",
    "DOUT_S_ROOT",
    "OCN_DOMAIN_FILE",
    "OCN_DOMAIN_PATH",
]


mkpath(parsed["root"])
cd(parsed["root"])


if isdir(parsed["casename"])
    throw(ErrorException(format("Error: `{:s}` already exists.", parsed["casename"])))
end

pleaseRun(`
$(parsed["cesm-root"])/scripts/create_newcase
    -case    $(parsed["casename"])
    -compset $(parsed["compset"])
    -res     $(parsed["resolution"])
    -mach    $(parsed["machine"])
`)

if !isdir(parsed["casename"])
    throw(ErrorException(format("Error: `{:s}` is not created")))
end

cd(parsed["casename"])


if parsed["user-namelist-dir"] != "" 
    println("copy user namelist")
    pleaseRun(`
        cp $(parsed["user-namelist-dir"])/user_nl_\* .
    `)
end

pleaseRun(`./cesm_setup`)


if parsed["env-run"] != ""
    for (key, val) in overwrite_env_run
        pleaseRun(`
            ./xmlchange -f env_run.xml -id $(key) -val $(val)
        `)
    end
end

if parsed["env-mach-pes"] != ""
    for (key, val) in overwrite_env_mach_pes
        pleaseRun(`
            ./xmlchange -f env_mach_pes.xml -id $(key) -val $(val)
        `)
    end
end

mv(format("{:s}.run", parsed["casename"]), format("{:s}.cesm.run", parsed["casename"]), force=true)

env_run = getXML("env_run.xml", [
    "CASEROOT",
    "RUNDIR",
    "DIN_LOC_ROOT",
    "DOUT_S_ROOT",
    "OCN_DOMAIN_FILE",
    "OCN_DOMAIN_PATH",
])

env_mach_pes = getXML("env_mach_pes.xml", [
    "TOTALPES",
    "MAX_TASKS_PER_NODE",
])


println("env_run data: ")
JSON.print(env_run, 4)


nodes = ceil(Int64, parse(Float64, env_mach_pes["TOTALPES"]) / parse(Float64, env_mach_pes["MAX_TASKS_PER_NODE"]))

open(joinpath(env_run["CASEROOT"], "$(parsed["casename"]).run"), "w") do io
    write(io, """
#PBS -A $(parsed["project"])
#PBS -N $(parsed["casename"])
#PBS -q $(parsed["queue"])
#PBS -l select=$(nodes):ncpus=$(env_mach_pes["MAX_TASKS_PER_NODE"]):mpiprocs=$(env_mach_pes["MAX_TASKS_PER_NODE"]):ompthreads=1
#PBS -l walltime="$(parsed["walltime"])"
#PBS -j oe
#PBS -S /bin/bash

#!/bin/bash

bash $(env_run["CASEROOT"]).destroy_tunnel
/bin/csh $(env_run["CASEROOT"])/$(parsed["casename"]).cesm.run &
$(env_run["CASEROOT"])/$(parsed["casename"]).ocn.run &
wait

""")
end

open(joinpath(env_run["CASEROOT"],"$(parsed["casename"]).ocn.run"), "w") do io
    write(io, """
#!/bin/bash
mpiexec -n $(parsed["ncpu"]) julia --project IOM/src/CESM_driver/main.jl --config-file=$(env_run["CASEROOT"])/config.jl

""")
end


# Create sh that removes x_tmp. This is useful when run on local machine for developing
open(joinpath(env_run["CASEROOT"], "$(parsed["casename"]).destroy_tunnel"), "w") do io
    write(io, """
#!/bin/bash
rm -rf $(env_run["RUNDIR"])/x_tmp/*
""", )
end

pleaseRun(`chmod +x $(parsed["casename"]).run`)
pleaseRun(`chmod +x $(parsed["casename"]).ocn.run`)
pleaseRun(`chmod +x $(parsed["casename"]).destroy_tunnel`)

pleaseRun(`git clone --branch "dev/cesm-coupling" https://github.com/meteorologytoday/IOM.git`)

cd(joinpath("SourceMods", "src.docn"))
pleaseRun(`ln -s ../../IOM/src/CESM_driver/cesm1_tb_docn_comp_mod.F90 ./docn_comp_mod.F90`)
pleaseRun(`ln -s ../../IOM/src/CESM_driver/ProgramTunnel .`)


