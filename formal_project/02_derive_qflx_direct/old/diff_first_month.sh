#!/bin/bash


ncks -F -O -d z_t,1,33 hist/paper2021_POP2_CTL.pop.h.daily.0003-01-01.nc daily_0003-01.nc
ncrename -d nlon,Nx -d nlat,Ny -d z_t,Nz daily_0003-01.nc
ncdiff -O Sandbox/archive/ocn/hist/Sandbox.EMOM.h1.day.0003-01.nc daily_0003-01.nc daily_diff.nc

