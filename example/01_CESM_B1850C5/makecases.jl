include("RunCommands.jl")

using .RunCommands
using Formatting

ocn_models = ["EMOM", "MLM", "SOM"]
EMOM_root = joinpath(@__DIR__, "..", "..")

casename_prefix = "EXAMPLE"
project_code = "UMIA0022"
walltime     = "12:00:00"
resolution   = "f09_g16"
machine      = "cheyenne"
compset      = "E1850C5"
cesm_env_file = "cesm_env.toml"
cesm_root    = "/glade/u/home/tienyiao/ucar_models/cesm1_2_2_1_lw-nudging" # Path to the root of CESM1 code
ncpu         = 16
cases_dir    = joinpath(@__DIR__, "cases") # This directory contains cases using members of hierarchy
inputdata_dir= joinpath(@__DIR__, "inputdata") # This directory contains inputdata needed by the ocean model such as domain files, Q-flux files, Nz_bot.nc and such
domain_file = "domain.ocn.gx1v6.090206.nc"
z_w_file = joinpath(inputdata_dir, "z_w.nc")
z_w_ref_file = "/glade/scratch/tienyiao/archive/CAM5_POP2/ocn/hist/CAM5_POP2.pop.h.0001-02.nc"
z_w_ref_file_convert_factor = - 0.01

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

    topo_file = joinpath(inputdata_dir, "Nz_bot_$(ocn_model).nc")
    init_file = "$(casename).init.snapshot.jld2"
    forcing_file = forcing_files[ocn_model]

    # Create init ocean restart files
    mkpath(inputdata_dir)

    if !isfile(dummy_config_file)    
        pleaseRun(pipeline(`julia $EMOM_root/tools/generate_init_files/make_blank_config.jl`, stdout = dummy_config_file))
    end

    if !isfile(z_w_file)

        # Generate z_w.nc with a referenced POP2 history file
        pleaseRun(`julia $(EMOM_root)/tools/generate_init_files/make_z_w.jl
                         --output-file $z_w_file 
                         --reference-file $z_w_ref_file
                         --reference-file-convert-factor $z_w_ref_file_convert_factor
        `)

        # The follwing is to generate z_w.nc with explicit numbers
        #=
        pleaseRun(`julia $EMOM_root/tools/generate_init_files/make_z_w.jl
                         --output-file $z_w_file 
                         --z_w 0 -10 -20 -30 -40 -50 -60 -70 -80 -90 -100 -120  -140  -160  -200

        =#
    end

    println("Making cesm generation script...")

    try

        pleaseRun(`julia $EMOM_root/tools/generate_cesm_case/make_cesm_sugar_script.jl
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
        `)

    catch e
        println(string(e))
        println("Something happened. Abort this case and move onto the next.")
        continue
    end
    #if [ ! "$?" = "0" ] ; then
    #    echo "Something went wrong when making cesm case. Skip this case."
#        continue
    pleaseRun(`julia $EMOM_root/tools/generate_init_files/makeConfigFromCESMCase.jl \
            --caseroot     $caseroot                    \
            --ocn-model    $ocn_model                   \
            --domain-file  $inputdata_dir/$domain_file  \
            --zdomain-file $inputdata_dir/$z_w_file \
            --topo-file    $inputdata_dir/$topo_file    \
            --init-file    $inputdata_dir/$init_file    \
            --forcing-file-HMXL $inputdata_dir/$forcing_file \
            --forcing-file-TEMP $inputdata_dir/$forcing_file \
            --forcing-file-SALT $inputdata_dir/$forcing_file \
            --forcing-file-QFLXT $inputdata_dir/$forcing_file \
            --forcing-file-QFLXS $inputdata_dir/$forcing_file \
            --forcing-time "0001-01-01 00:00:00" "0002-01-01 00:00:00" "0001-01-01 00:00:00"
    `)

    for (target_nml_file, provided_nml_file) in user_namelists
        if isfile(provided_nml_file)
            cp(provided_nml_file, joinpath(caseroot, target_nml_file), force=true)
        end
    end
end
