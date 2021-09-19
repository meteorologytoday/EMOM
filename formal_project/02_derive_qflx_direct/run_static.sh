#!/bin/bash

#PBS -A UCIR0040
#PBS -N QFLX_static
#PBS -q economy
#PBS -l select=1:ncpus=36:mpiprocs=36:ompthreads=1
#PBS -l walltime=12:00:00
#PBS -j oe

ml load openmpi/4.0.3
julia --project -e 'ENV["JULIA_MPI_BINARY"]="system"; using Pkg; Pkg.build("MPI"; verbose=true)'


wdir=/glade/u/home/tienyiao/paper2021/24_compute_Qflx_direct
LID=$( date +%y%m%d-%H%M%S )

mpiexec -n 12 julia --project     \
    main.jl                       \
        --config-file $wdir/data/config_static.toml \
        --hist-dir    $wdir/hist  \
        --year-rng    2 22   2>&1 > iom_static.${LID}.log
