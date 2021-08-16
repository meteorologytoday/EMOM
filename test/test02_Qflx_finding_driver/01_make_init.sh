#!/bin/bash

source 00_setup.sh

ncks -O -F -d z_t,1,${needed_layers} -d z_w,1,$(( needed_layers + 1 )) $POP2_profile_full_layers $POP2_profile_g16

ncremap -m CESM_domains/remap_files/g16_to_g37/wgt.neareststod.nc $POP2_profile_g16 $POP2_profile_g37

# There are some problems in CyclicData.jl. For now just use the following stupid method.
ncatted -a units,time,m,c,"days since 0001-01-01 00:00:00" \
        -a units,time_bound,m,c,"days since 0001-01-01 00:00:00" \
        $POP2_profile_g37


julia make_init.jl

