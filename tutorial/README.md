# Goal

This tutorial folder contains 


## `01_CESM1_B1850C5CN_POP2`

This project is a reference case that using purely CESM1 (i.e. with POP2).

1. Edit the `create_newcase`, `project` and such in the `makecase_CAM5_POP2.sh` to fit your environment.
2. Execute `makecase_CAM5_POP2.sh f09_g16` to generate the run with the resolution `f09_g16`. To generate a lower resolution run `f45_g37`, execute `makecase_CAM5_POP2.sh f45_g37`.
3. Follow the usual CESM1 procedure: `cesm_setup`, build and submit.
4. Check if POP2 has the daily output.

## `02_derive_reference_profile`

This project is to generate the reference profile for the hierarchy. The reference output is from `01_CESM1_B1850C5CN_POP2`.

1. Edit the options in `run.sh` to fit your setup.
2. Execute `main.sh`

## `03_find_flux_correction`

This project generates the CESM1 runs that couple with each model member to find the flux corrections `QFLXT`, and `QFLXS`.


## `04_derive_flux_correction`

This project is to generate the actual

1. Edit the options in `make_forcing_one_case.sh` to fit your setup.
2. Execute `make_forcing_one_case.sh`.
3. The file `make_forcing_batch.sh` gives an example of making flux correction files of the entire hierarchy.

## `05_CESM1_B1850C5CN_hierarchy`

This project generates the desire CESM1 runs that couple with each model member and use the found flux corrections from previous projects.
