#!/bin/bash

domain_file=CESM_domains/domain.ocn.gx1v6.090206.nc
forcing_file=forcing.nc

julia 01_generate_forcing_file.jl                                \
    --POP2-monthly-profile paper2021_CTL_POP2.0001-0100.complete.nc \
    --n-layers 40                                                \
    --domain-file=$domain_file                                   \
    --output-dir output \
    --output-forcing-file forcing.nc

julia 02_tool_check_if_domain_topo_and_forcing_mask_consistent.jl \
    --domain-file $domain_file       \
    --zdomain-file output/z_w.nc     \
    --topo-file    output/Nz_bot.nc  \
    --forcing-file output/forcing.nc


julia 03_make_init.jl \
    --config-file config.jl
 
