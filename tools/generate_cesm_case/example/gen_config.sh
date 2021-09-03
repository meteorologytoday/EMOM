#!/bin/bash

julia IOM/tools/generate_config/makeConfigFromCESMCase.jl \
    --caseroot /glade/u/home/tienyiao/paper2021/POP2/paper2021_CTL_POP2 \
    --domain-file inputdata/domain.ocn.gx1v6.090206.nc \
    --zdomain-file inputdata/forcing.g16.nc \
    --topo-file inputdata/Nz_bot.nc\
    --forcing-file inputdata/forcing.g16.nc \
    --init-file inputdata/init_ocn.jld2 \
    --ocn-model "EOM" \
    --output-path `pwd`
 
