#!/bin/bash

wdir=$(realpath -s $(dirname $0))

POP2_profile_full_layers=$wdir/paper2021_CTL_POP2.0001-0100.nc

needed_layers=33

DOMAIN_FILE_g16=$wdir/CESM_domains/domain.ocn.gx1v6.090206.nc
POP2_data_dir_g16=$wdir/data_g16

#POP2_data_dir_g37=$wdir/data_g37
#DOMAIN_FILE=CESM_domains/domain.ocn.gx3v7.120323.nc
#POP2_profile_used=$POP2_profile_g37

DOMAIN_FILE_used=$DOMAIN_FILE_g16
POP2_data_dir_used=$POP2_data_dir_g16


if [ ! -d "data" ]; then
    mkdir $wdir/data
fi
