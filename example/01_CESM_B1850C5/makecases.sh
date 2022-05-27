#!/bin/bash

project_code=UCIR0040
walltime=12:00:00
resolution=f09_g16
machine=cheyenne
cesm_root=/glade/u/home/tienyiao/ucar_models/cesm1_2_2_1_lw-nudging
ncpu=7
cases_dir=`pwd`/cases
inputdata_dir=`pwd`/inputdata
domain_file=domain.ocn.gx1v6.090206.nc


#for ocn_model in SOM ; do #MLM EMOM ; do
for ocn_model in MLM EMOM ; do

    if [ "$ocn_model" = "SOM" ] ; then
        topo_file=Nz_bot_SOM.nc
    else
        topo_file=Nz_bot.nc
    fi


    casename=qco2_${ocn_model}

    julia EMOM/tools/generate_cesm_case/make_cesm_sugar_script.jl \
        --project $project_code  \
        --casename $casename     \
        --root $cases_dir        \
        --walltime $walltime     \
        --resolution $resolution \
        --compset E1850          \
        --machine $machine       \
        --cesm-root $cesm_root   \
        --cesm-env cesm_env.toml \
        --ncpu $ncpu 

    if [ ! "$?" = "0" ] ; then
        echo "Something went wrong when making cesm case. Skip this case."
#        continue
    fi

        
    init_file=paper2021_${ocn_model}_coupled.snapshot.0201-01-01-00000.jld2

    if [ "$ocn_model" = "EMOM" ]; then 
        forcing_file=forcing.CO2012.g16.211014.coupled.rm_mean.nc
    elif [ "$ocn_model" = "MLM" ]; then
        forcing_file=forcing.MLM.g16.211014.coupled.rm_mean.nc
    elif [ "$ocn_model" = "SOM" ]; then
        forcing_file=forcing.SOM.g16.211014.coupled.rm_mean.nc
    else
        echo "ERROR: unknown ocean modeal '${ocn_model}'."
        exit 1
    fi

    zdomain_file=${forcing_file}
    caseroot=$cases_dir/$casename

    julia EMOM/tools/generate_init_files/makeConfigFromCESMCase.jl \
        --caseroot     $caseroot                    \
        --ocn-model    $ocn_model                   \
        --domain-file  $inputdata_dir/$domain_file  \
        --zdomain-file $inputdata_dir/$zdomain_file \
        --topo-file    $inputdata_dir/$topo_file    \
        --init-file    $inputdata_dir/$init_file    \
        --forcing-file-HMXL $inputdata_dir/$forcing_file \
        --forcing-file-TEMP $inputdata_dir/$forcing_file \
        --forcing-file-SALT $inputdata_dir/$forcing_file \
        --forcing-file-QFLXT $inputdata_dir/$forcing_file \
        --forcing-file-QFLXS $inputdata_dir/$forcing_file \
        --forcing-time "0001-01-01 00:00:00" "0002-01-01 00:00:00" "0001-01-01 00:00:00"


    cp ../simulation_shared_files/shared_user_namelist/user_nl_cam_monthly $caseroot/user_nl_cam

    echo "co2vmr=1138.8e-6" >> $caseroot/user_nl_cam

    caserun=/glade/u/home/tienyiao/scratch-tienyiao/$casename/run
    cp /glade/u/home/tienyiao/scratch-tienyiao/archive/paper2021_${ocn_model}_CTL_coupled/rest/0201-01-01-00000/* $caserun


done
