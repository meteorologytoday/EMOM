#!/bin/bash

wdir=$(pwd)

rm -rf project
mkdir project

ln -s domain.nc project/domain.nc

cd project
julia $wdir/make_forcing.jl --domain domain.nc
julia $wdir/make_config.jl
