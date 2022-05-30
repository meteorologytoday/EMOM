#!/bin/bash

LID=$( date +%y%m%d )


for model in MLM SOM ; do

    qflx_file=forcing.${model}.g16.${LID}.coupled.nc
    qflx_file_rm_mean=forcing.${model}.g16.${LID}.coupled.rm_mean.nc

    julia make_forcing_from_hist.jl \
        --hist-dir $HOME/scratch-tienyiao/archive/paper2021_${model}_QFLX/ocn/hist \
        --year-rng 2 20       \
        --data-dir output_0002-0051_layers33  \
        --output-file $qflx_file

    julia IOM/tools/derive_QFLX/remove_QFLX_mean.jl \
        --input-file $qflx_file                     \
        --output-file $qflx_file_rm_mean

done

if [ ] ; then
julia make_forcing_from_hist.jl \
    --hist-dir $HOME/scratch-tienyiao/archive/paper2021_EMOM_QFLX/ocn/hist \
    --year-rng 2 20       \
    --data-dir output_0002-0051_layers33  \
    --output-file forcing.CO2012.g16.${LID}.coupled.nc
fi

