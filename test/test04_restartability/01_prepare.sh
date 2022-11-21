#!/bin/bash

wdir=$(pwd)

rm -rf project
mkdir project

ln -s ../EMOM/data/CESM_domains/domain.lnd.fv4x5_gx3v7.091218.nc project/domain.nc

cd project
julia $wdir/make_forcing.jl --domain domain.nc
julia $wdir/make_config.jl
