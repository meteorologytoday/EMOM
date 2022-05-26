#!/bin/bash

wdir=$( realpath -s $(pwd) )
config_file=$wdir/data/config.toml
Nz_bot_file=$wdir/data/Nz_bot.nc
z_w_file=$wdir/data/z_w.nc
ncpu=2


domain=gx3v7
echo "Domain is set as: $domain"
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

