#!/bin/bash

source 00_setup.sh

julia tool_check_if_domain_topo_and_forcing_mask_consistent.jl \
    --domain-file $DOMAIN_FILE                                 \
    --zdomain-file z_w.nc                                      \
    --topo-file Nz_bot.nc                                      \
    --forcing-file $POP2_profile_used                          \
    --forcing-file-xdim "nlon" \
    --forcing-file-ydim "nlat" \
    --forcing-file-zdim "z_t"
 



