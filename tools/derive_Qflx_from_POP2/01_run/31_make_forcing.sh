#/bin/bash

if [ "$1" = "" ] ; then
    echo "Error: casename must be supplied as an argument. "
    exit 1
fi

source 00_setup.sh

casename=$1
hist_root=projects/$casename/archive/ocn/hist

beg_yr=2
end_yr=2

yr_rng_str=$( printf "%04d-%04d" $beg_yr $end_yr )
yr_rng=$( printf "{%04d..%04d}" $beg_yr $end_yr )

# Making mean profile

mkdir -p tmp
for m in $( seq 1 12 ) ; do

    m_str=$( printf "%02d" $m )
    echo "Doing month $m_str"
    eval "ncra -v WKRSTT,WKRSTS,dz_cT,area_sT -O $hist_root/*.h0.*.${yr_rng}-${m_str}.nc tmp/monthly_mean_${m_str}.nc"

done

ncrcat -O tmp/monthly_mean_{01..12}.nc $forcing_file
ncks -O -3 $forcing_file $forcing_file
ncrename -d Nx,nlon -d Ny,nlat -d Nz,z_t -v WKRSTT,QFLX_TEMP -v WKRSTS,QFLX_SALT $forcing_file
ncap2 -O -s 'QFLX_TEMP=QFLX_TEMP*3996*1026;' $forcing_file $forcing_file
ncks -A -v SALT,TEMP,HMXL,time,z_w_top,z_w_bot $POP2_profile_used $forcing_file
ncks -O -F -d z_t,1,$forcing_file_layers $forcing_file $forcing_file
