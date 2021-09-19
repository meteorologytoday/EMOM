#!/bin/bash

ml load mpi

wdir=$(pwd)
LID=$( date +%y%m%d-%H%M%S )
mpiexec -n 6 julia --project     \
    main.jl                       \
        --config-file $wdir/data/config_test.toml \
        --hist-dir    $wdir/hist  \
        --year-rng    2 2
