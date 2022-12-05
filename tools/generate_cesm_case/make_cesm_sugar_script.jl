using ArgParse
using Formatting
using JSON,TOML
using DataStructures


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

function getCESMConfig(path, ids)

    wdir = pwd()

    cd(path)

    d = OrderedDict()
    for id in ids
        d[id] = readchomp(`./xmlquery $(id) -silent -valonly`)
    end

    cd(wdir)

    return d
end

function setCESMConfig(path, filename, kv_list)

    wdir = pwd()
    cd(path)
    for (key, val) in kv_list
        pleaseRun(`
            ./xmlchange -f $(filename) -id $(key) -val $(val)
        `)
    end
    cd(wdir)
end


s = ArgParseSettings()
@add_arg_table s begin

    "--project"
        help = "Project code sent to PBS scheduling system"
        arg_type = String
        required = true

    "--casename"
        help = "Casename"
        arg_type = String
        required = true

    "--root"
        help = "The folder where case folders are contained"
        arg_type = String
        required = true


    "--ncpu"
        help = "The number of CPUs that EMOM can use"
        arg_type = Int64
        required = true


    "--walltime"
        help = "Walltime sent to PBS scheduling system"
        arg_type = String
        required = true

    "--queue"
        help = "Queue sent to PBS scheduling system"
        arg_type = String
        default = "economy"


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

    "--cesm-env"
        help = "The TOML file used to set env_mach_pes.xml, env_run.xml"
        arg_type = String
        default = ""

    "--build"
        help = "If set then will try to build the case."
        action = :store_true

    "--git-branch"
        help = "The version you are checkout. "
        arg_type = String
        default = "main"

end

parsed = DataStructures.OrderedDict(parse_args(ARGS, s))

JSON.print(parsed, 4)

if parsed["cesm-env"] != ""
    overwrite_cesm_env = TOML.parsefile(parsed["cesm-env"]) |> DataStructures.OrderedDict
    println("Loaded env file ", parsed["cesm-env"])
    JSON.print(overwrite_cesm_env, 4)
else
    overwrite_cesm_env = Dict()
end

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

println("Entering case folder $(parsed["casename"])")
cd(parsed["casename"])


if parsed["user-namelist-dir"] != "" 
    println("copy user namelist")
    pleaseRun(`
        cp $(parsed["user-namelist-dir"])/user_nl_\* .
    `)
end

for k in ["env_run", "env_mach_pes"]
    if haskey(overwrite_cesm_env, k)
        setCESMConfig(pwd(), "$(k).xml", overwrite_cesm_env[k])
    end
end

pleaseRun(`./cesm_setup`)
pleaseRun(`./cesm_setup -clean`)
pleaseRun(`./cesm_setup`)


cesm_env = getCESMConfig(pwd(), [
    "CASEROOT",
    "RUNDIR",
    "DIN_LOC_ROOT",
    "DOUT_S_ROOT",
    "OCN_DOMAIN_FILE",
    "OCN_DOMAIN_PATH",
    "TOTALPES",
    "MAX_TASKS_PER_NODE",
])


println("env data: ")
JSON.print(cesm_env, 4)

# The $casename.run file is created by cesm_setup and mk_batch files in CESM1 util codes
cp("$(parsed["casename"]).run", "$(parsed["casename"]).cesm.run", force=true)



cesm_nodes = ceil(Int64, parse(Float64, cesm_env["TOTALPES"]) / parse(Float64, cesm_env["MAX_TASKS_PER_NODE"]))

open(joinpath(cesm_env["CASEROOT"], "$(parsed["casename"]).run"), "w") do io
    write(io, """
#PBS -A $(parsed["project"])
#PBS -N $(parsed["casename"])
#PBS -q $(parsed["queue"])
#PBS -l select=$(cesm_nodes+1):ncpus=$(cesm_env["MAX_TASKS_PER_NODE"]):mpiprocs=$(cesm_env["MAX_TASKS_PER_NODE"]):ompthreads=1
#PBS -l walltime="$(parsed["walltime"])"
#PBS -j oe
#PBS -S /bin/bash

#!/bin/bash

bash $(cesm_env["CASEROOT"])/$(parsed["casename"]).destroy_tunnel
/bin/csh $(cesm_env["CASEROOT"])/$(parsed["casename"]).cesm.run &
$(cesm_env["CASEROOT"])/$(parsed["casename"]).ocn.run &
wait

""")
end

open(joinpath(cesm_env["CASEROOT"],"$(parsed["casename"]).ocn.run"), "w") do io
    write(io, """
#!/bin/bash

LID=\$( date +%y%m%d-%H%M%S )

caseroot="$(cesm_env["CASEROOT"])"
caserun="$(cesm_env["RUNDIR"])"
archive_log_dir="$(cesm_env["DOUT_S_ROOT"])/ocn/logs"
logfile="emom.log.\${LID}"
EMOM_ROOT=\${caseroot}/EMOM

ml load openmpi/4.0.3
ml load julia/1.7.1
julia -e 'ENV["JULIA_MPI_BINARY"]="system"; using Pkg; Pkg.build("MPI"; verbose=true)'


mpiexec -n $(parsed["ncpu"]) julia \${EMOM_ROOT}/src/CESM_driver/main.jl --config-file=\${caseroot}/config.toml &> \${caserun}/\${logfile}


ret_code=\$?
echo "Return code: \$ret_code"

if [ \$ret_code -eq 0 ]; then 
    echo "Program ends succefully. Move log file to arcihve."
    mv "\${caserun}/\${logfile}" "\${archive_log_dir}/"
else
    echo "Program ends abnomally. Please check."
fi


""")
end


# Create sh that removes x_tmp. This is useful when run on local machine for developing
open(joinpath(cesm_env["CASEROOT"], "$(parsed["casename"]).destroy_tunnel"), "w") do io
    write(io, """
#!/bin/bash
rm -rf $(cesm_env["RUNDIR"])/x_tmp/*
""", )
end

# If user clean_build and rerun cesm_setup, the run file will be overwritten.
cp("$(parsed["casename"]).run", "backup_$(parsed["casename"]).run", force=true)
open(joinpath(cesm_env["CASEROOT"],"$(parsed["casename"]).recover_run_file"), "w") do io
    write(io, """
#!/bin/bash
cp "$(parsed["casename"]).run" "$(parsed["casename"]).cesm.run"
cp "backup_$(parsed["casename"]).run" "$(parsed["casename"]).run"

""")
end

pleaseRun(`chmod +x $(parsed["casename"]).run`)
pleaseRun(`chmod +x $(parsed["casename"]).ocn.run`)
pleaseRun(`chmod +x $(parsed["casename"]).destroy_tunnel`)
pleaseRun(`chmod +x $(parsed["casename"]).recover_run_file`)


open(joinpath(cesm_env["CASEROOT"],"user_nl_cam"), "w") do io
    write(io, """
nhtfrq=0
empty_htapes=.true.
fincl1='SOLIN','FSUTOA','FLUT','FLUTC','CLDHGH','CLDLOW','CLDMED','CLDTOT','FLDS','FLNS','FSDS','FSDSC','FSNS','FSNSC','FLNT','FSNT','ICEFRAC','LHFLX','LWCF','PHIS','PRECC','PRECL','PRECSC','PRECSL','PS','PSL','QFLX','QREFHT','SHFLX','SNOWHICE','SNOWHLND','SWCF','TAUX','TAUY','TMQ','TREFHT','TS','U10','CLOUD','OMEGA','Q','T','U','V','VT','VU','VQ','Z3','SST'
""")
end

pleaseRun(`git clone --branch "$(parsed["git-branch"])" https://github.com/meteorologytoday/EMOM.git`)

cd(joinpath("SourceMods", "src.docn"))
pleaseRun(`ln -s ../../EMOM/src/CESM_driver/cesm1_tb_docn_comp_mod.F90 ./docn_comp_mod.F90`)
pleaseRun(`ln -s ../../EMOM/src/CESM_driver/ProgramTunnel .`)

cd(joinpath("..", ".."))


if parsed["build"]
    pleaseRun(`./$(parsed["casename"]).build`)
end
