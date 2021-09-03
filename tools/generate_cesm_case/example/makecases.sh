#!/bin/bash

project_code=UCIR0040
walltime=12:00:00
resolution=f09_g16
machine=cheyenne
cesm_root=/glade/u/home/tienyiao/ucar_models/cesm1_2_2_1_lw-nudging
ncpu=12
cases_dir=`pwd`/cases
inputdata_dir=`pwd`/inputdata
domain_file=domain.ocn.gx1v6.090206.nc
zdomain_file=forcing.g16.nc
forcing_file=forcing.g16.nc
init_file=init_ocn.jld2
topo_file=Nz_bot.nc

for ocn_model in EOM ; do

    casename=paper2021_${ocn_model}_CTL

    julia IOM/tools/generate_cesm_case/make_cesm_sugar_script.jl \
        --project $project_code  \
        --casename $casename     \
        --root $cases_dir        \
        --walltime $walltime     \
        --resolution $resolution \
        --compset E1850          \
        --machine $machine       \
        --cesm-root $cesm_root   \
        --cesm-env cesm_env.toml \
        --ncpu 12                

    if [ ! "$?" = "0" ] ; then
        echo "Something went wrong when making cesm case. Abort."
        exit 1
    fi

    julia IOM/tools/generate_config/makeConfigFromCESMCase.jl \
        --caseroot     $cases_dir/$casename        \
        --domain-file  $inputdata_dir/$domain_file  \
        --zdomain-file $inputdata_dir/$zdomain_file \
        --topo-file    $inputdata_dir/$topo_file    \
        --forcing-file $inputdata_dir/$forcing_file \
        --init-file    $inputdata_dir/$init_file    \
        --ocn-model    $ocn_model 
     
done
