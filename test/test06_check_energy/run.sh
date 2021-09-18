#!/bin/bash

wdir=$( pwd )

mpiexec -n $1 julia --project     \
    main.jl                       \
        --config-file data/config.toml
