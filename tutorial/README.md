# Goal

This tutorial folder contains the steps to derive the flux correction as described in the paper.

## Setup Julia package

The Julia programming language is needed (version >= 1.7). Follow the steps to install the necessary tools. Run `julia tools/julia_dependency/add_pkgs.jl` to setup all the packages. 

## Step 1: Creating reference case (`01_CESM1_B1850C5CN_POP2`)

This project is a reference case that using purely CESM1 (i.e. with POP2).

1. Edit the `create_newcase`, `project` and such in the `makecase_CAM5_POP2.sh` to fit your environment.
2. Execute `makecase_CAM5_POP2.sh f09_g16` to generate the run with the resolution `f09_g16`. To generate a lower resolution run `f45_g37`, execute `makecase_CAM5_POP2.sh f45_g37`.
3. Follow the usual CESM1 procedure: `cesm_setup`, build and submit.
4. Check if POP2 has the daily output.

## Step 2: Derive reference profile (`02_derive_reference_profile`)

This project is to generate the reference profile for the hierarchy. The reference output is from `01_CESM1_B1850C5CN_POP2`.

1. Edit the options in `run.sh` to fit your setup.
2. Execute `main.sh`

## Step 3: Find flux correction (`03_find_flux_correction`)

This project generates the CESM1 runs that couple with each model member to find the flux corrections `QFLXT`, and `QFLXS`.
1. Edit the environment variable in the beginning part of the `makecases.jl`. Most importantly the `forcing_files` needs to be set. The variable `ocn_models` is an array specifying which members of the hierarchy you want to generate the case with.
2. Run `julia makecase.jl`.
3. Follow the usual CESM1 procedure: `cesm_setup`, build.
4. The usual cesm run file is renamed as `$CASENAME.cesm.run`. The new submit file is still `$CASENAME.run`. If users accidentally lost the `$CASENAME.run` file, run `$CASENAME.recover_run_file` to regenerate it.
5. After the cases are all done, users are able to move onto stage 4 to derive the flux correction.


## Step 4: Derive flux correction (`04_derive_flux_correction`)

This project is to generate the flux correction files that will be used by the model

1. Edit the options in `make_forcing_one_case.sh` to fit your setup.
2. Execute `make_forcing_one_case.sh`.
3. The file `make_forcing_batch.sh` gives an example of making flux correction files of the entire hierarchy.

## Step 5: Setup the hierarchy for usage (`05_CESM1_B1850C5`)

This project generates the desire CESM1 runs that couple with each model member and use the found flux corrections from previous projects.

1. Edit the environment variable in the beginning part of the `makecases.jl`. The variable `ocn_models` is an array specifying which members of the hierarchy you want to generate the case with.
2. Run `julia makecase.jl`. Make sure in the config files, `Qflx` and `weak_restoring` are on and `Qflx_finding` is off.
4. Follow the usual CESM1 procedure: `cesm_setup`, build.
5. The usual cesm run file is renamed as `$CASENAME.cesm.run`. The new submit file is still `$CASENAME.run`. If users accidentally lost the `$CASENAME.run` file, run `$CASENAME.recover_run_file` to regenerate it.
