#!/bin/bash

scheme=AGA

for keyword in 1day 5day; do

    ncap2 -O -v -s '*dz=dz_cT(:, 0, 0);*QFLXTdz[$time,$Nz,$Ny,$Nx]=dz*QFLXT;intQFLXTdz=QFLXTdz.ttl($Nz);' Sandbox/archive_${scheme}_${keyword}/ocn/hist/Sandbox.EMOM.h0.mon.0003-01.nc compare_${scheme}_${keyword}.nc 

done
