#!/bin/bash

if [ "$1" = "" ]; then

    echo "Need to provide number of cores you want to use."
    exit 1;

fi


mpiexec -n $1 julia --project main.jl --stop-n=4 --time-unit=month  --read-restart=false


