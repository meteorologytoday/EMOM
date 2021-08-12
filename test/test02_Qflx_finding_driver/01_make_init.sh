#!/bin/bash

ncks -O -F -d z_t,1,33 -d z_w,1,34 paper2021_CTL_POP2.100years.nc paper2021_CTL_POP2.100years.33layers.g16.nc
ncremap -m CESM_domains/remap_files/g16_to_g37/wgt.bilinear.nc paper2021_CTL_POP2.100years.33layers.g16.nc paper2021_CTL_POP2.100years.33layers.g37.nc

ncatted -a units,time,m,c,"days since 0001-01-01 00:00:00" \
        -a units,time_bound,m,c,"days since 0001-01-01 00:00:00" \
        paper2021_CTL_POP2.100years.33layers.g37.nc


julia make_init.jl


