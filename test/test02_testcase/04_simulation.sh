#!/bin/bash

source 02_setup.sh

mpiexec -n $ncpu julia --project     \
    main.jl                       \
        --config-file data/config.toml

