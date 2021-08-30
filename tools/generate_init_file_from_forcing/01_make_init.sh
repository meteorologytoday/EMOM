#!/bin/bash

source 00_setup.sh

ncks -O -F -d z_t,1,${needed_layers}     \
           -d z_w_top,1,${needed_layers} \
           -d z_w_bot,1,${needed_layers} \
           $POP2_profile_full_layers $POP2_profile_g16

ncap2 -O -v -s 'time_bound=time_bound;'  \
            -s 'z_t=-z_t/100.0;'         \
            -s 'z_w_top=-z_w_top/100.0;' \
            -s 'z_w_bot=-z_w_bot/100.0;' \
            -s 'TEMP=TEMP;'              \
            -s 'SALT=SALT;'              \
            -s 'SWFLX=-SHF_QSW;'         \
            -s 'NSWFLX=-(SHF-SHF_QSW);'  \
            -s 'VSFLX=SFWF;'             \
            -s 'HMXL=HBLT/100.0;'        \
            -s 'TAUX=TAUX/10.0;'         \
            -s 'TAUY=TAUY/10.0;'         \
             $POP2_profile_g16 $POP2_profile_g16


ncremap -m CESM_domains/remap_files/g16_to_g37/wgt.neareststod.nc $POP2_profile_g16 $POP2_profile_g37

# There are some problems in CyclicData.jl. For now just use the following stupid method.
for f in $POP2_profile_g16 $POP2_profile_g37 ; do
    ncatted -a units,time,m,c,"days since 0001-01-01 00:00:00" \
            -a units,time_bound,m,c,"days since 0001-01-01 00:00:00" \
            $f
done


julia make_init.jl

