#!/bin/bash

ncrcat -O -v TEMP,SALT,NSWFLX,SWFLX,VSFLX,ADVT,ADVS,area_sT,dz_cT Sandbox/archive/ocn/hist/Sandbox.EMOM.h0.mon.0001-*.nc check_budget.nc
ncwa -O -a N1 check_budget.nc check_budget.nc

ncap2 -O -v -s "*VOL[Nz,Ny,Nx]=dz_cT*area_sT;"               \
            -s '*TOTAL_VOL=VOL.total($Nx,$Ny,$Nz);'          \
            -s '*TOTAL_AREA=area_sT.total($Nx,$Ny);'         \
            -s "INT_TEMP[time,Nz,Ny,Nx]=TEMP*VOL;"           \
            -s "INT_SALT[time,Nz,Ny,Nx]=SALT*VOL;"           \
            -s "INT_NSWFLX[time,Ny,Nx]=NSWFLX*area_sT;"      \
            -s "INT_SWFLX[time,Ny,Nx]=SWFLX*area_sT;"        \
            -s "INT_VSFLX[time,Ny,Nx]=VSFLX*area_sT;"        \
            -s 'TOT_SFCFLXT=INT_NSWFLX.total($Nx,$Ny)+INT_SWFLX.total($Nx,$Ny);' \
            -s 'TOT_SFCFLXS=INT_VSFLX.total($Nx,$Ny);'       \
            -s 'TOTAL_INPUTT=TOT_SFCFLXT.total($time)/TOTAL_AREA;'    \
            -s 'TOTAL_INPUTS=TOT_SFCFLXS.total($time)/TOTAL_AREA;'    \
            -s 'AVG_TEMP=INT_TEMP.total($Nx,$Ny,$Nz)/TOTAL_VOL;'      \
            -s 'AVG_SALT=INT_SALT.total($Nx,$Ny,$Nz)/TOTAL_VOL;'      \
            check_budget.nc check_budget2.nc
