#!/bin/bash

LID=$( date +%y%m%d )

model=MLM
qflx_file=forcing.${model}.g16.${LID}.coupled.nc
qflx_file_rm_mean=forcing.${model}.g16.${LID}.coupled.rm_mean.nc
hist_dir=/seley/tienyiah/paper2021_simulation/paper2021_${model}_QFLX/ocn/hist
# data_dir is the folder output from 02_derive_reference_profile that contains the reference TEMP, SALT, HMXL and such
data_dir=../02_derive_reference_profile/output

year_beg=2
year_end=2
output_folder=output

julia ../../tools/derive_QFLX/make_forcing_from_hist.jl \
    --hist-dir $hist_dir \
    --year-rng $year_beg $year_end       \
    --data-dir $data_dir \
    --output-file $output_folder/$qflx_file

julia ../../tools/derive_QFLX/remove_QFLX_mean.jl \
    --input-file $output_folder/$qflx_file        \
    --output-file $output_folder/$qflx_file_rm_mean


