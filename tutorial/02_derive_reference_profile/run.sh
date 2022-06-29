#!/bin/bash

casename=CAM5_POP2_f09_g16
#casename=paper2021_POP2_CTL
layers=33
hist_dir=/glade/scratch/tienyiao/archive/$casename/ocn/hist


julia lib/make_climatology_from_reference_case.jl \
    --hist-dir $hist_dir    \
    --output-dir output     \
    --casename $casename    \
    --layers $layers        \
    --year-rng 2 2
