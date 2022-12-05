#!/bin/bash

ncpu=2

./make_domain.sh
./run_with_mpi.sh $ncpu
