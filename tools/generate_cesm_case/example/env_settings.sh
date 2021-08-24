#!/bin/bash

env_run=(
    STOP_OPTION       nyears
    STOP_N            10
    OCN_NCPL          1 
    CONTINUE_RUN      FALSE
    RESUBMIT          19
    DOCN_SOM_FILENAME "pop_frc.gx3v7.110128.nc"
)

env_mach_pes=(
    NTASKS_ATM 32
    ROOTPE_ATM  0
    NTASKS_LND 32
    ROOTPE_LND  0
    NTASKS_ICE 32
    ROOTPE_ICE  0
    NTASKS_OCN  1
    ROOTPE_OCN 32
    NTASKS_CPL 32
    ROOTPE_CPL  0
    NTASKS_GLC 32
    ROOTPE_GLC  0
    NTASKS_ROF 32
    ROOTPE_ROF  0
    NTASKS_WAV 32
    ROOTPE_WAV  0
)

