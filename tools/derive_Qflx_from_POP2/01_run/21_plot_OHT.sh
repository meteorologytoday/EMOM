#!/bin/bash

if [ "$1" = "" ] ; then

    echo "Error: casename must be supplied as an argument. "

    exit 1
fi


source 00_setup.sh

mkdir -p img

casename=$1
hist_root=projects/$casename/archive/ocn/hist

beg_yr=2
end_yr=2

yr_rng_str=$( printf "%04d-%04d" $beg_yr $end_yr )
yr_rng=$( printf "{%04d..%04d}" $beg_yr $end_yr )

# Making mean profile

mean_annual=mean_${yr_rng_str}_annual
mean_01=mean_${yr_rng_str}_01
mean_07=mean_${yr_rng_str}_07


eval "ncra -O $hist_root/*.h0.*.${yr_rng}-{01..12}.nc ${mean_annual}.nc"
eval "ncra -O $hist_root/*.h0.*.${yr_rng}-01.nc ${mean_01}.nc"
eval "ncra -O $hist_root/*.h0.*.${yr_rng}-07.nc ${mean_07}.nc"

for casename in $mean_annual $mean_01 $mean_07 ; do

    julia plot_OHT.jl --input-file ${casename}.nc --output-img img/${casename}.png --no-display

done
