#!/bin/bash

julia calculate_posterior_2D.jl --scheme CO2012  &
julia calculate_posterior_2D.jl --scheme KSC2018 &
julia calculate_posterior_2D.jl --scheme AGA2020 &

wait
