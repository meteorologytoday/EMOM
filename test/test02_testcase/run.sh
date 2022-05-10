#!/bin/bash

wdir=$( realpath -s $(pwd) )

echo "Making an empty ocean with constant temperature and salinity."

echo "Making config..."
mkdir data
julia $wdir/EMOM/tools/generate_init_files/makeBlankConfig.jl > $wdir/data/config.toml
julia set_config.jl --config $wdir/data/config.toml

if [ ] ; then
mpiexec -n $1 julia --project     \
    main.jl                       \
        --config-file data/config.toml


fi
