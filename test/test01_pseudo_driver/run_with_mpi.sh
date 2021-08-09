#!/bin/bash

mpiexec -n 2 julia --project main.jl --stop-n=1 --time-unit=month  --read-restart=false

