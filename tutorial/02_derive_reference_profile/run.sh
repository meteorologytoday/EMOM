#!/bin/bash

#casename=CAM5_POP2_f09_g16
casename=paper2021_POP2_CTL
layers=2 # 2 #33
#    --hist-dir /glade/scratch/tienyiao/archive/$casename/ocn/hist \
julia lib/make_climatology_from_reference_case.jl \
    --hist-dir /seley/tienyiah/paper2021_simulation/$casename/ocn/hist \
    --output-dir output           \
    --casename $casename \
    --layers $layers                   \
    --year-rng 2 2
