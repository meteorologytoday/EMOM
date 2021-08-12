#!/bin/bash

mpiexec -n $1 julia --project   \
    main.jl                     \
        --stop-n=1              \
        --time-unit=month       \
        --config-file=config.jl \
        --forcing-file=$( pwd )/paper2021_CTL_POP2.100years.33layers.g37.nc
