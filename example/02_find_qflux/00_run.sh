#!/bin/bash

julia make_daily_climatology_from_reference_case.jl \
    --hist-dir /glade/u/home/tienyiao/scratch-tienyiao/archive/paper2021_POP2_CTL/ocn/hist \
    --output-dir output           \
    --casename paper2021_POP2_CTL \
    --year-rng 2 3
