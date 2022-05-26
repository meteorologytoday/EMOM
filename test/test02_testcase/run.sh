#!/bin/bash

wdir=$( realpath -s $(pwd) )
config_file=$wdir/data/config.toml


echo "Making data folder."
mkdir data

echo "Making config."
julia $wdir/EMOM/tools/generate_init_files/make_blank_config.jl > $config_file
julia set_config.jl --config $wdir/data/config.toml

echo "Making an empty ocean with constant temperature and salinity."
julia $wdir/EMOM/tools/generate_init_files/make_init_ocean.jl \
    --config $config_file

if [ ] ; then
mpiexec -n $1 julia --project     \
    main.jl                       \
        --config-file data/config.toml


fi
