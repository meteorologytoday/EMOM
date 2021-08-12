#!/bin/bash

set -x

vars="const_flux,TFLUX_DIV_implied"


ncks -O -3 LENS_piControl_oQ_3_rerun_f45_g37_SOM_EKMAN_20.ocn.h.monthly.0001.nc tmp.nc
ncrename -d Nx,ni -d Ny,nj tmp.nc
ncap2 -O -s "const_flux=h_ML*0+1.0;" tmp.nc data_old.nc
ncks -A -v area,mask /seley/tienyiah/CESM_domains/domain.ocn.gx3v7.120323.nc data_old.nc 
ncwa -O -b -a ni,nj -B 'mask==1' data_old.nc avg_data_old.nc

cp domain.ocn.gx3v7.120323.ESMF.nc data_src.nc
cp domain.lnd.fv4x5_gx3v7.091218.ESMF.nc data_dst.nc

ncks -A -v $vars data_old.nc data_src.nc


ESMF_Regrid -s data_src.nc -d data_dst.nc --src_var $vars --dst_var $vars


exit

julia transform_data_ESMF.jl  \
    --w-file=w.nc     \
    --s-file=LENS_piControl_oQ_3_f45_g37_NKOM_EKMAN_20.ocn.h.monthly.0021.nc  \
    --d-file=test.nc  \
    --vars=T,h_ML    \
    --x-dim=Nx        \
    --y-dim=Ny        \
    --z-dim=Nz_bone   \
    --t-dim=time  
