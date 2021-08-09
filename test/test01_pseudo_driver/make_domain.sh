#!/bin/bash

ref_file=domain.lnd.fv4x5_gx3v7.091218.nc

file_with_mask=domain.ocn.fv4x5_gx3v7.091218.nc
file_without_mask=domain.ocn_aqua.fv4x5_gx3v7.091218.nc



ncap2 -O -s "'mask'=1.0-'mask';" $ref_file $file_with_mask
ncap2 -O -s "'mask'='mask'*0+1; 'mask'(0:1,:)=0;'mask'(-2:-1,:)=0;" $ref_file $file_without_mask
