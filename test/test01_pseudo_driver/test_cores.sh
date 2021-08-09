#!/bin/bash

mpiexec -n 7 julia --project main.jl --stop-n=5 --time-unit=day  --read-restart=false
cp Sandbox/archive/ocn/hist/Sandbox.EMOM.h1.day.0001-01.nc result_core07.nc


mpiexec -n 5 julia --project main.jl --stop-n=5 --time-unit=day  --read-restart=false
cp Sandbox/archive/ocn/hist/Sandbox.EMOM.h1.day.0001-01.nc result_core05.nc

ncdiff -O result_core07.nc  result_core05.nc diff_0705.nc
