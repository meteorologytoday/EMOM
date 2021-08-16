#!/bin/bash

mpiexec -n $1 julia --project main.jl --stop-n=1 --time-unit=year  --read-restart=false

for t in $( seq 2 10 ); do
    mpiexec -n $1 julia --project main.jl --stop-n=1 --time-unit=year  --read-restart=true
done

