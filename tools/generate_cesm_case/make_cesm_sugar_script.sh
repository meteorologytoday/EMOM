#!/bin/bash

wk_dir=$( dirname $0 )
echo $( basename $0 )
echo "wk_dir: $wk_dir"

lopts=(
    casename
    code-output-dir
    init-file
    label
    resolution
    walltime
    project-code
    compset
    machine
    cesm-create-newcase
    cesm-env
    user-namelist-dir
    vt-scheme
    hz-scheme
    ocn-ncpu
    qflux-file
    seaice-file
    ocn-branch
    single-job
)

source $wk_dir/getopt_helper.sh



if [ -z "$casename" ]; then
    echo "ERROR: --casename not provided."
    exit 1;
fi

script_file=$code_output_dir/makecase_$casename.sh

# Clean the file
echo -ne "" > $script_file 

cat $wk_dir/lib_XML.sh >> $script_file

cat << EOF >> $script_file

casename=$casename
resolution=$resolution
machine=$machine
compset=$compset
user_namelist_dir=$user_namelist_dir
init_file=$init_file
qflux_file="$qflux_file"
seaice_file="$seaice_file"

walltime="${walltime}"
single_job="${single_job}"


export PROJECT=${project_code}

env_vars=(
    caseroot           CASEROOT
    caserun            RUNDIR
    din_loc_root       DIN_LOC_ROOT
    dout_s_root        DOUT_S_ROOT 
    ocn_domain_file    OCN_DOMAIN_FILE
    ocn_domain_path    OCN_DOMAIN_PATH
    totalpes           TOTALPES
    max_tasks_per_node MAX_TASKS_PER_NODE
)
EOF

cat $cesm_env >> $script_file

cat << EOF >> $script_file

if [ -d \$casename ]; then
    echo "Error: \$casename already exists. Abort."
    exit 1;
fi



$cesm_create_newcase         \\
    -case      \$casename    \\
    -compset   \$compset     \\
    -res       \$resolution  \\
    -mach      \$machine

if [ ! -d \$casename ] ; then
    echo "Error: \$casename is not properly created. Abort."
    exit 1;
fi


cd \$casename


if [ ! -z "\$qflux_file" ]; then

    echo "Qflux file nonempty. Now setting user-defined qflux."
    setXML "env_run.xml" "DOCN_SOM_FILENAME" "\$qflux_file"
 
    FORCING_DIR=\$( dirname \$qflux_file )
    FORCING_FILENAME=\$( basename \$qflux_file )

    cat << XEOFX > user_docn.streams.txt.som
    $( echo "$( cat $wk_dir/docn_stream.txt )" )

XEOFX
 
fi

if [ ! -z "\$seaice_file" ]; then

    seaice_setting=(
        SSTICE_DATA_FILENAME "\$seaice_file"
        SSTICE_GRID_FILENAME "\$seaice_file"
        SSTICE_YEAR_ALIGN 1
        SSTICE_YEAR_START 1
        SSTICE_YEAR_END 1
    )

    setXML "env_run.xml" "\${seaice_setting[@]}"

fi

setXML "env_run.xml" "\${env_run[@]}"
setXML "env_mach_pes.xml" "\${env_mach_pes[@]}"



# copy user namelist
if [ "\$user_namelist_dir" != "" ]; then
    cp \$user_namelist_dir/user_nl_* .
fi


# Must setup here to get calculated TOTALPES
./cesm_setup

getXML "\${env_vars[@]}"

nodes=\$( python -c "from math import ceil; print('%d' % (ceil(float(\${totalpes}) / float(\${max_tasks_per_node})),));" )

cat << XEOFX > config.jl

let
global overwrite_configs = Dict(
    :casename                   => "\${casename}",
    :caseroot                   => "\${caseroot}",
    :caserun                    => "\${caserun}",
    :domain_file                => "\${ocn_domain_path}/\${ocn_domain_file}",
    :archive_root               => "\${dout_s_root}",
    :enable_archive             => true,
    :daily_record               => [],
    :monthly_record             => :ESSENTIAL,
    :yearly_snapshot            => true,
    :substeps                   => 8,
    :init_file                  => "\${init_file}",
)
end

XEOFX

cat << XEOFX >> config.jl
$( cat $wk_dir/init_code/HOOM_${vt_scheme}_${hz_scheme}/config.jl )
XEOFX


cat << XEOFX > \$casename.ocn.run

#!/bin/bash
#PBS -N \$casename-ocn
#PBS -l walltime=\$walltime
#PBS -q share
### Merge output and error files
#PBS -j oe
#PBS -l select=1:ncpus=$ocn_ncpu:mpiprocs=$ocn_ncpu
### Send email on abort, begin and end
#PBS -m abe
#PBS -M meteorologytoday@gmail.com

### Run the ocean vt_scheme ###

LID="\\\$(date +%y%m%d-%H%M)"
ocn_code="\$caseroot/SMARTSLAB-main/src/CESM_driver/run.jl"
config_file="\$caseroot/config.jl"
ocn_ncpu=$ocn_ncpu

logfile="HOOM.log.\\\$LID"
logarchivedir="\${dout_s_root}/ocn/logs"

julia -p \\\$ocn_ncpu \\\$ocn_code --config="\\\$config_file" --core=HOOM | tee -a \${caserun}/\\\${logfile}

mkdir -p \\\$logarchivedir
mv \${caserun}/\\\${logfile} \\\${logarchivedir}
gzip -f \\\${logarchivedir}/\\\${logfile}

XEOFX



mv \${casename}.run \${casename}.cesm.run

# ===== JOB SUBMISSION BLOCK BEGIN =====


# Create sh that removes x_tmp. This is useful when run on local machine for developing
cat << XEOFX > \${casename}.destroy_tunnel
#!/bin/bash

rm -rf \${caserun}/x_tmp/*
XEOFX

if [ "\$single_job" != "on" ]; then

    echo "single_job != on. Use 2 jobs to complete a run."

    # "BATCHSUBMIT" is used when automatically resubmitting the job
    # Currently the design is to submit batch job through another script
    # file. So BATCHSUBMIT is set to just bash.
    setXML "env_run.xml" "BATCHSUBMIT" "bash"

    cat << XEOFX > \${casename}.run
#!/bin/bash

bash \${casename}.destroy_tunnel
qsub -A \$PROJECT -l walltime="\$walltime" \${caseroot}/\${casename}.ocn.run
qsub -A \$PROJECT -l walltime="\$walltime" \${caseroot}/\${casename}.cesm.run 
XEOFX

else
    echo "single_job = on. Use 1 job to complete a run."

#    if [ "\$nodes" -gt "1" ]; then
#        echo "ERROR: Only 1 node is allowed when single_job variable is set as 'on'."
#        exit 1
#    fi

    # Single job Run (Experimental. Currently may only works on a single node because CESM 
    # was designed to take all the resources of each nodes. This scripts needs "env_mach_pes.xml"
    # configured correctly. If a single node got N cores. It would be M cores for cesm and (N-M)
    # cores for ocn vt_scheme.
    
    cat << XEOFX > \${casename}.run
#PBS -A \${PROJECT}
#PBS -N \${casename}
#PBS -q regular
#PBS -l select=\${nodes}:ncpus=\${max_tasks_per_node}:mpiprocs=\${max_tasks_per_node}:ompthreads=1
#PBS -l walltime="\${walltime}"
#PBS -j oe
#PBS -S /bin/bash

#!/bin/bash

bash \${casename}.destroy_tunnel
/bin/csh \${caseroot}/\${casename}.cesm.run &
\${caseroot}/\${casename}.ocn.run &
wait

XEOFX
fi

# ===== JOB SUBMISSION BLOCK END =====

chmod +x \$casename.ocn.run
chmod +x \$casename.run
chmod +x \$casename.destroy_tunnel

# Insert code
git clone --branch "$ocn_branch" https://github.com/meteorologytoday/SMARTSLAB-main.git

cd ./SourceMods/src.docn
ln -s ../../SMARTSLAB-main/src/CESM_driver/cesm1_tb_docn_comp_mod.F90 ./docn_comp_mod.F90
ln -s ../../SMARTSLAB-main/src/CESM_driver/ProgramTunnel .


EOF

chmod +x $script_file 

echo "$casename"
