#!/bin/bash

julia lib/make_daily_climatology_from_reference_case.jl \
    --hist-dir /seley/tienyiah/paper2021_simulation/paper2021_POP2_CTL/ocn/hist \
    --output-dir output           \
    --casename paper2021_POP2_CTL \
    --layers 33                   \
    --year-rng 2 2
