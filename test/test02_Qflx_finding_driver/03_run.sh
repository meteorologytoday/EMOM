#!/bin/bash

source 00_setup.sh

mpiexec -n $1 julia --project   \
    main.jl                     \
        --stop-n=21             \
        --time-unit=year        \
        --config-file=config.jl \
        --forcing-file=$( pwd )/$POP2_profile_used
