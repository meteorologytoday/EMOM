#!/bin/bash

ml load mpi

wdir=$(pwd)
pdir=$wdir/project

mpiexec -n $1 julia --project           \
    $wdir/main.jl                      \
        --config-file   $pdir/config.toml \
        --stop-n        1              \
        --time-unit     month          \
        --atm-forcing   $pdir/atm_forcing.nc 




project/Sandbox/archive/ocn/hist/Sandbox.EMOM.h0.mon.0001-01.nc
