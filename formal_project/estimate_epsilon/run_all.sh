#!/bin/bash

julia calculate_posterior.jl --scheme CO2012  &
julia calculate_posterior.jl --scheme KSC2018 &
julia calculate_posterior.jl --scheme AGA2020 &

wait
