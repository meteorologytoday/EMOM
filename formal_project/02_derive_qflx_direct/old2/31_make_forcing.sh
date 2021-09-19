#!/bin/bash

julia make_forcing_from_hist.jl --hist-dir projects/EMOM_addU_QFLX_NUDGING/archive/ocn/hist --year-rng 2 20 --data-dir data_g16 --output-file data_g16/forcing_cyclic.NUDGING.nc
