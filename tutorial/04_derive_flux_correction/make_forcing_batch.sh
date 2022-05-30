#!/bin/bash

LID=$( date +%y%m%d )
mkdir output

for model in SOM MLM EMOM ; do

    qflx_file=forcing.${model}.g16.${LID}.coupled.nc
    qflx_file_rm_mean=forcing.${model}.g16.${LID}.coupled.rm_mean.nc

    julia ../../tools/derive_QFLX/make_forcing_from_hist.jl \
        --hist-dir /seley/tienyiah/paper2021_simulation/paper2021_${model}_QFLX/ocn/hist \
        --year-rng 2 2       \
        --data-dir ../02_derive_reference_profile/output  \
        --output-file output/$qflx_file

    julia ../../tools/derive_QFLX/remove_QFLX_mean.jl \
        --input-file output/$qflx_file                     \
        --output-file output/$qflx_file_rm_mean

done

