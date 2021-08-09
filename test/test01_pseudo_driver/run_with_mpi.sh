#!/bin/bash

mpiexec -n $1 julia --project main.jl --stop-n=10 --time-unit=day  --read-restart=false

