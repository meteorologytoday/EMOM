# Goal

This tutorial folder contains 


## `01_CESM1_B1850C5CN_POP2`

This is a reference case that using purely CESM1 (i.e. with POP2).

1. Edit the `create_newcase`, `project` and such in the `makecase_CAM5_POP2.sh` to fit your environment.
2. Execute `makecase_CAM5_POP2.sh f09_g16` to generate the run with the resolution `f09_g16`. To generate resolution run, execute `makecase_CAM5_POP2.sh f45_g37`.
3. Follow the usual CESM1 procedure: `cesm_setup`, build and submit.
4. Check if the program has the daily output.

## `02_derive_reference_profile`

1. Edit the options in `run.sh` to fit your setup.
2. Execute `main.sh`

