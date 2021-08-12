#!/bin/bash

mpiexec -n $1 julia --project   \
    main.jl                     \
        --stop-n=10              \
        --time-unit=day       \
        --config-file=config.jl \
        --forcing-file=$( pwd )/paper2021_CTL_POP2.100years.33layers.g37.nc
