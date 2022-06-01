include("RunCommands.jl")

using .RunCommands
using Formatting

ocn_models = ["EMOM", "MLM", "SOM"]
EMOM_root = joinpath(@__DIR__, "..", "..")

git_branch = "dev/wrap-up"
casename_prefix = "EXAMPLE"
project_code = "UMIA0022"
walltime     = "12:00:00"
resolution   = "f09_g16"
machine      = "cheyenne"
compset      = "E1850C5"
cesm_env_file = "cesm_env.toml"
cesm_root    = "/glade/u/home/tienyiao/ucar_models/cesm1_2_2_1_lw-nudging" # Path to the root of CESM1 code
ncpu         = 18
cases_dir    = joinpath(@__DIR__, "cases") # This directory contains cases using members of hierarchy
inputdata_dir= joinpath(@__DIR__, "inputdata") # This directory contains inputdata needed by the ocean model such as domain files, Q-flux files, Nz_bot.nc and such
domain_file = joinpath(EMOM_root, "data", "CESM_domains", "domain.ocn.gx1v6.090206.nc")
z_w_file = joinpath(inputdata_dir, "z_w.nc")
POP2_hist_file = "/glade/scratch/tienyiao/archive/CAM5_POP2/ocn/hist/CAM5_POP2.pop.h.0001-02.nc"
POP2_hist_file_z_convert_factor    = - 0.01
POP2_hist_file_hmxl_convert_factor =   0.01
POP2_hist_ref_var = "TEMP"

forcing_files = Dict(
    "SOM" => "",
    "MLM" => "",
    "EMOM" => "",
)

user_namelists = Dict(
    "user_nl_cam" => joinpath(@__DIR__, "user_nl_cam"),
)

dummy_config_file = joinpath(inputdata_dir, "dummy_config.toml")

for ocn_model in ocn_models
    
    casename = "$(casename_prefix)_$(ocn_model)"
    caseroot = joinpath(cases_dir, casename)
    EMOM_config_file = joinpath(caseroot, "config.toml")

    Nz_bot_file = joinpath(inputdata_dir, "Nz_bot_$(ocn_model).nc")
    init_file = joinpath(inputdata_dir, "$(casename).init.snapshot.jld2")

    forcing_file = forcing_files[ocn_model]
    if ! isfile(forcing_file)
        println("Forcing file $forcing_file does not exist. Re-assign forcing file as empty.")
        forcing_file = ""
    end


    # Create init ocean restart files
    mkpath(inputdata_dir)

    if !isfile(dummy_config_file)    
        pleaseRun(pipeline(`julia --project=$EMOM_root $EMOM_root/tools/generate_init_files/make_blank_config.jl`, stdout = dummy_config_file))
    end

    if !isfile(z_w_file)

        # Generate z_w.nc with a referenced POP2 history file
        pleaseRun(`julia --project=$EMOM_root $(EMOM_root)/tools/generate_init_files/make_z_w.jl
                         --output-file $z_w_file 
                         --reference-file $POP2_hist_file
                         --reference-file-convert-factor $POP2_hist_file_z_convert_factor
        `)

    end

    if !isfile(Nz_bot_file)
        
        # Generate z_w.nc with a referenced POP2 history file
        pleaseRun(`julia --project=$EMOM_root $EMOM_root/tools/generate_init_files/make_Nz_bot_from_ref_file.jl
                         --ref-file $POP2_hist_file
                         --ref-var $POP2_hist_ref_var
                         --domain-file $domain_file 
                         --z_w-file $z_w_file
                         --HMXL-file $POP2_hist_file 
                         --HMXL-convert-factor $POP2_hist_file_hmxl_convert_factor
                         --SOM $(ocn_model == "SOM")
                         --output-file $Nz_bot_file
        `)

    end

    if !isfile(init_file)

        # Set dummy config here because every model uses its own Nz_bot file
        pleaseRun(`julia --project=$EMOM_root $EMOM_root/tools/generate_init_files/set_dummy_config.jl
            --domain-file  $domain_file
            --z_w-file     $z_w_file
            --Nz_bot-file  $Nz_bot_file
            --config       $dummy_config_file
        `)
 
        pleaseRun(`julia --project=$EMOM_root $EMOM_root/tools/generate_init_files/make_init_ocean.jl --config $dummy_config_file --output-filename $init_file`)
    end

    println("Making cesm generation script...")

    try

        pleaseRun(`julia --project=$EMOM_root $EMOM_root/tools/generate_cesm_case/make_cesm_sugar_script.jl
            --project $project_code  
            --casename $casename     
            --root $cases_dir        
            --walltime $walltime     
            --resolution $resolution 
            --compset $compset        
            --machine $machine       
            --cesm-root $cesm_root   
            --cesm-env $cesm_env_file
            --ncpu $ncpu
            --git-branch $git_branch
        `)

    catch e
        println(string(e))
        println("Something happened. Abort this case and move onto the next.")
        continue
    end

    pleaseRun(`julia --project=$EMOM_root $EMOM_root/tools/generate_init_files/make_config_from_CESM_case.jl 
            --caseroot     $caseroot                    
            --ocn-model    $ocn_model                  
            --domain-file  $domain_file  
            --z_w-file $z_w_file 
            --Nz_bot-file    $Nz_bot_file    
            --init-file    $init_file    
            --forcing-file-HMXL $forcing_file 
            --forcing-file-TEMP $forcing_file 
            --forcing-file-SALT $forcing_file 
            --forcing-file-QFLXT $forcing_file
            --forcing-file-QFLXS $forcing_file 
            --forcing-time "0001-01-01 00:00:00" "0002-01-01 00:00:00" "0001-01-01 00:00:00"
            --output-filename $(EMOM_config_file)
    `)
    
    # Activate the flux-correction mode
    pleaseRun(`julia --project=$EMOM_root activate_finding_flux_correction.jl
            --config       $(EMOM_config_file)
    `)
 

    println("Validate the generated config file: $(EMOM_config_file)")
    pleaseRun(`julia --project=$EMOM_root $EMOM_root/tools/generate_init_files/validate_config.jl --config $EMOM_config_file`)

    for (target_nml_file, provided_nml_file) in user_namelists
        if isfile(provided_nml_file)
            cp(provided_nml_file, joinpath(caseroot, target_nml_file), force=true)
        end
    end

end
