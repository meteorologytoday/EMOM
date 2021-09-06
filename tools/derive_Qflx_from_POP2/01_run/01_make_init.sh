#!/bin/bash


source 00_setup.sh


for ocn_model in "EMOM" ; do
    #for mode in "NUDGING" "VERIFYING" ; do
    for mode in "NUDGING" ; do

        casename=${ocn_model}_addU_QFLX

        julia makeConfig.jl \
            --casename "$casename" \
            --mode $mode \
            --project-root "$wdir/projects" \
            --domain-file "$DOMAIN_FILE_used" \
            --zdomain-file "$POP2_data_dir_used/coord.nc" \
            --ref-clim-dir "$POP2_data_dir_used"     \
            --ocn-model "$ocn_model"
 
        julia makeRun.jl \
            --config-file "$wdir/projects/$casename_${mode}/caseroot/config.toml" \
            --project-code "UCIR0040"
    
        julia makeInit.jl \
            --init-profile-TEMP "$POP2_data_dir_used/TEMP.nc" \
            --init-profile-SALT "$POP2_data_dir_used/SALT.nc" \
            --init-profile-HMXL "$POP2_data_dir_used/HMXL.nc" \
            --config-file "$wdir/projects/$casename_${mode}/caseroot/config.toml"
    done
done


