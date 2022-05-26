#!/bin/bash

domain=gx3v7

echo "Domain is set as: $domain"

wdir=$( realpath -s $(pwd) )
config_file=$wdir/data/config.toml
Nz_bot_file=$wdir/data/Nz_bot.nc
z_w_file=$wdir/data/z_w.nc

if [ "$domain" = "gx1v6" ] ; then 
    domain_file=$wdir/CESM_domains/domain.ocn.gx1v6.090206.nc
    topo_file=$wdir/CESM_domains/ocean_topog_gx1v6.nc
elif [ "$domain" = "gx3v7" ] ; then 
    domain_file=$wdir/CESM_domains/domain.ocn.gx3v7.120323.nc
    topo_file=""
elif [ "$domain" = "fv4x5" ] ; then 
    domain_file=$wdir/CESM_domains/domain.lnd.fv4x5_gx3v7.091218.nc
    topo_file=""
else
    echo "Error: Unknown domain \"$domain\"."
    exit 1
fi

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

if [ ] ; then
mpiexec -n $1 julia --project     \
    main.jl                       \
        --config-file data/config.toml


fi
