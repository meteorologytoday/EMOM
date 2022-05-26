#!/bin/bash

source 02_setup.sh

echo "Making data folder."
mkdir data

echo "Making config."
julia $wdir/EMOM/tools/generate_init_files/make_blank_config.jl > $config_file

julia $wdir/EMOM/tools/generate_init_files/make_z_w.jl \
    --output-file $z_w_file \
    --z_w 0 -10 -20 -30 -40 -50 -60 -70 -80 -90 -100 -120  -140  -160  -200

julia $wdir/EMOM/tools/generate_init_files/make_Nz_bot_from_topo.jl \
    --output-file $Nz_bot_file \
    --domain-file $domain_file \
    --z_w-file $z_w_file \
    --topo-file "$topo_file"

julia set_config.jl --config $wdir/data/config.toml

#echo "Making an empty ocean with constant temperature and salinity."
julia $wdir/EMOM/tools/generate_init_files/make_init_ocean.jl \
    --config $config_file
