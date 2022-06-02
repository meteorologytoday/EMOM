#!/bin/bash

casename=CAM5_POP2_f09_g16

julia lib/make_daily_climatology_from_reference_case.jl \
    --hist-dir /glade/scratch/tienyiao/archive/$casename/ocn/hist \
    --output-dir output           \
    --casename $casename \
    --layers 33                   \
    --year-rng 2 2
