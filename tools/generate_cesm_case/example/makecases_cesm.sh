#!/bin/bash

pwd_dir=$(pwd)

echo "Current directory: $pwd_dir"
compset=E_1850_CN_SPINUPOCN
machine=xtt-centos-intel
project_code=UCIR0029

cases_dir=$pwd_dir/cases
label=LENS
raw_data_dir=$pwd_dir/raw_data

T_file=$raw_data_dir/avg_b.e11.B1850C5CN.f09_g16.005.pop.h.TEMP.100001-109912.nc
S_file=$raw_data_dir/avg_b.e11.B1850C5CN.f09_g16.005.pop.h.SALT.100001-109912.nc

resolution=f45_g37

topo_file=$raw_data_dir/ocean_topog_gx1v6.nc

old_domain=$raw_data_dir/domain.ocn.gx1v6.090206.nc
new_domain=$raw_data_dir/domain.ocn.gx3v7.120323.nc
#new_domain=$raw_data_dir/domain.ocn.gx1v6.090206.nc

code_output_dir=$pwd_dir/cesm_scripts
init_files_dir=$pwd_dir/init_cond
cesm_env=$pwd_dir/env_settings.sh

ocn_ncpu=3
ocn_branch=master

single_job="on"

model_settings=(
    NKOM  oQ_oC         "$raw_data_dir/docn_forcing.EntOM_xM.LENS.g37.nc"
    NKOM  xQ_oC         ""
    NKOM  xQ_xC         ""
    NKOM  EntOM_oQ_xM   "$raw_data_dir/docn_forcing.EntOM_xM.LENS.g37.nc"
    NKOM  EntOM_oQ_oM   "$raw_data_dir/docn_forcing.EntOM_xM.LENS.g37.nc"
    NKOM  SOM_oQ        "$raw_data_dir/docn_forcing.SOM.LENS.g37.nc"
    NKOM  SOM_xQ        ""
)

models=(
    NKOM_SOM    "$raw_data_dir/docn_forcing.SOM.LENS.g37.nc"
    NKOM_EntOM  "$raw_data_dir/docn_forcing.EntOM.LENS.g37.nc"
    NKOM_FULL   ""
)

flow_schemes=(
    oEK
    xEK
)


relaxation_times=(
    "0"
    "20"
    "100"
)


casenames=()

for i in $(seq 1 $((${#models[@]}/2))); do
    model=${models[$((2*(i-1)))]}
    qflux_file=${models[$((2*(i-1)+1))]}

    for j in $(seq 1 $((${#flow_schemes[@]}/1))); do
        flow_scheme=${flow_schemes[$((1*(j-1)))]}

        for k in $(seq 1 $((${#relaxation_times[@]}/1))); do
            relaxation_time=${relaxation_times[$((1*(k-1)))]}


            echo "##### MAKING: $model $flow_scheme $relaxation_time #####"

            SMARTSLAB-main/other_src/generate_cesm_case/main.sh \
                --code-output-dir=$code_output_dir              \
                --init-files-dir=$init_files_dir                \
                --label=$label                                  \
                --resolution=$resolution                        \
                --walltime="06:00:00"                           \
                --data-clim-T-file=$T_file                      \
                --data-clim-S-file=$S_file                      \
                --topo-file=$topo_file                          \
                --old-domain-file=$old_domain                   \
                --new-domain-file=$new_domain                   \
                --T-unit=C                                      \
                --S-unit=PSU                                    \
                --cesm-create-newcase=~/ucar_models/cesm1_2_2_1/scripts/create_newcase \
                --compset=$compset                              \
                --machine=$machine                              \
                --model=$model                                  \
                --flow-scheme=$flow_scheme                      \
                --cesm-env=$cesm_env                            \
                --ocn-ncpu=$ocn_ncpu                            \
                --project-code=$project_code                    \
                --qflux-file=$qflux_file                        \
                --ocn-branch=$ocn_branch                        \
                --single-job="$single_job"                      \
                --relaxation-time=$relaxation_time                      \
                | tee tmp.txt

                casenames+=($(tail -n 1 tmp.txt))
        done
    done
done

all_cmd="$code_output_dir/00_all_cmd.sh"
all_clean_build="$code_output_dir/01_all_clean_build.sh"
all_makecase="$code_output_dir/02_all_makecase.sh"
all_build="$code_output_dir/03_all_build.sh"
all_run="$code_output_dir/04_all_run.sh"


for file in $all_makecase $all_build $all_clean_build $all_run $all_cmd ; do
    echo "#!/bin/bash" > $file
    echo "p=\$(pwd)" >> $file
    chmod +x $file
done

echo "mkdir -p $cases_dir" >> $all_makecase
echo "cd $cases_dir" >> $all_makecase


for casename in "${casenames[@]}"; do
   
    echo "Making all files for : $casename"
 
    case_dir=$cases_dir/$casename

    echo "$code_output_dir/makecase_${casename}.sh" >> $all_makecase 
    echo "cd $case_dir; ./cesm_setup; ./${casename}.build; cd \$p" >> $all_build 
    echo "cd $case_dir; ./${casename}.clean_build; ./cesm_setup -clean; cd \$p" >> $all_clean_build 

    echo "if [ \$1 = \"cesm\" ] ; then cd $case_dir; elif [ \$1 = \"ocn\" ] ; then cd $case_dir/SMARTSLAB-main; else echo \"ERROR: First arg not 'cesm' nor 'ocn'.\"; exit 1; fi; echo \$(pwd); \${@:2}; cd \$p" >> $all_cmd

    if [ "$single_job" != "on" ]; then
        echo "cd $case_dir; ./${casename}.run; cd \$p" >> $all_run
    else
        echo "cd $case_dir; qsub ./${casename}.run; cd \$p" >> $all_run
    fi
done

echo "Done."
