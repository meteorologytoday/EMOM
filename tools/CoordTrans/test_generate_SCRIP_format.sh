#!/bin/bash


julia generate_SCRIP_format.jl \
    --input-file=/seley/tienyiah/CESM_domains/domain.ocn.gx3v7.120323.nc    \
    --output-file=domain.ocn.gx3v7.120323.SCRIP.nc    \
    --center-lon=xc     \
    --center-lat=yc     \
    --corner-lon=xv     \
    --corner-lat=yv     \
    --mask-value=1.0    

julia generate_SCRIP_format.jl \
    --input-file=/seley/tienyiah/CESM_domains/domain.lnd.fv4x5_gx3v7.091218.nc    \
    --output-file=domain.lnd.fv4x5_gx3v7.091218.SCRIP.nc    \
    --center-lon=xc     \
    --center-lat=yc     \
    --corner-lon=xv     \
    --corner-lat=yv     \
    --mask-value=0.0    

#ESMF_RegridWeightGen -s domain.ocn.gx3v7.120323.SCRIP.nc -d domain.lnd.fv4x5_gx3v7.091218.SCRIP.nc -m conserve -w w.nc --user_areas --check
#ESMF_Scrip2Unstruct domain.ocn.gx3v7.120323.SCRIP.nc        domain.ocn.gx3v7.120323.ESMF.nc       0 ESMF
#ESMF_Scrip2Unstruct domain.lnd.fv4x5_gx3v7.091218.SCRIP.nc  domain.lnd.fv4x5_gx3v7.091218.ESMF.nc 0 ESMF
#mpirun -np 4 ESMF_RegridWeightGen -s domain.ocn.gx3v7.120323.SCRIP.nc -d domain.lnd.fv4x5_gx3v7.091218.SCRIP.nc -m conserve2nd -w w.nc --user_areas --check
