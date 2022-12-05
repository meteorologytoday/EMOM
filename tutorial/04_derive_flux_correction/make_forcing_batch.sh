#!/bin/bash

LID=$( date +%y%m%d )
data_dir=/glade/u/home/tienyiao/work-tienyiao/projects/CAM4_coupling/EMOM/tutorial/02_derive_reference_profile/output

mkdir output



#for model in SOM MLM EMOM ; do
for model in SOM MLM ; do

    qflx_file=forcing.${model}.g16.${LID}.coupled.nc
    qflx_file_rm_mean=forcing.${model}.g16.${LID}.coupled.rm_mean.nc

    julia ../../tools/derive_QFLX/make_forcing_from_hist.jl \
        --hist-dir /glade/scratch/tienyiao/archive/CAM4_QFLX_FND_FRZHEAT_${model}/ocn/hist \
        --year-rng 2 20       \
        --data-dir $data_dir \
        --output-file output/$qflx_file

    julia ../../tools/derive_QFLX/remove_QFLX_mean.jl \
        --input-file output/$qflx_file                     \
        --output-file output/$qflx_file_rm_mean

done

