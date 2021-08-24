#!/bin/bash

export wk_dir=$( dirname "$(realpath $0)" )
#echo "wk_dir: $wk_dir"

lopts=(
    casename
    code-output-dir
    init-files-dir
    label
    resolution
    walltime
    new-layers
    domain-file
    cesm-create-newcase
    cesm-env
    user-namelist-dir
    compset
    machine
    project-code
    vt-scheme
    hz-scheme
    ocn-ncpu
    ocn-branch
    forcing-file
    single-job
    relaxation-time
    vertical-resolution
)

source $wk_dir/getopt_helper.sh

cat << EOF

Users should be aware that domain file your are providing should
coincide with the ocean domain that is being used by CESM. This
is an inevitable pivot that cannot be overcome for now.

EOF

echo "Checking user name list directory"
if [ ! -z "$user_namelist_dir" ] && [ ! -d "$user_namelist_dir" ]; then
    echo "ERROR: --user-namelist-dir $user_namelist_dir dose not exist. "
    exit 1
fi

echo "Making directories..."
mkdir -p $code_output_dir
mkdir -p $init_files_dir


if [ -z "$ocn_branch" ] ; then
    ocn_branch=master
fi


echo "Making initial files..."

new_data_clim_T_file=$init_files_dir/clim_T_${label}_${resolution}_$( basename $data_clim_T_file ".nc" ).nc
new_data_clim_S_file=$init_files_dir/clim_S_${label}_${resolution}_$( basename $data_clim_S_file ".nc" ).nc
#new_data_init_T_file=$init_files_dir/init_T_${label}_${resolution}_$( basename $data_init_T_file ".nc" ).nc
#new_data_init_S_file=$init_files_dir/init_S_${label}_${resolution}_$( basename $data_init_S_file ".nc" ).nc
#new_data_init_MLD_file=$init_files_dir/init_MLD_${label}_${resolution}_$( basename $data_init_MLD_file ".nc" ).nc
new_topo_file=$init_files_dir/${label}_${resolution}_$( basename $topo_file ".nc" ).nc

zdomain_file=$init_files_dir/HOOM_zdomain.nc

$wk_dir/make_init.sh                            \
    --output-dir=$init_files_dir                \
    --label=$label                              \
    --input-clim-T-file=$data_clim_T_file       \
    --input-clim-S-file=$data_clim_S_file       \
    --input-topo-file=$topo_file                \
    --output-clim-T-file=$new_data_clim_T_file  \
    --output-clim-S-file=$new_data_clim_S_file  \
    --output-init-T-file=$new_data_init_T_file  \
    --output-init-S-file=$new_data_init_S_file  \
    --output-init-MLD-file=$new_data_init_MLD_file  \
    --output-topo-file=$new_topo_file           \
    --old-domain-file=$old_domain_file          \
    --new-domain-file=$new_domain_file          \
    --T-unit=$T_unit                            \
    --output-zdomain-file=$zdomain_file         \
    --output-resolution=$vertical_resolution


echo "Making initial files for a specific vt_scheme"

if [ -z "$casename" ]; then
    casename=${label}_${resolution}_${vt_scheme}_${hz_scheme}_${relaxation_time}
fi

init_file=$init_files_dir/init_${casename}.nc

$wk_dir/make_init_each_model.sh                 \
    --output-file=$init_file                    \
    --label=$label                              \
    --data-clim-T-file=$new_data_clim_T_file    \
    --data-clim-S-file=$new_data_clim_S_file    \
    --domain-file=$new_domain_file              \
    --zdomain-file=$zdomain_file                \
    --topo-file=$new_topo_file                  \
    --T-unit=$T_unit                            \
    --S-unit=$S_unit                            \
    --forcing-file=$qflux_file                  \
    --vt-scheme=$vt_scheme                              \
    --hz-scheme=$hz_scheme                  \
    --relaxation-time=$relaxation_time


echo "Generate cesm sugar scripts..."

$wk_dir/make_cesm_sugar_script.sh           \
    --casename=$casename                    \
    --code-output-dir=$code_output_dir      \
    --init-file=$init_file                  \
    --resolution=$resolution                \
    --label=$label                          \
    --walltime="$walltime"                  \
    --project-code="$project_code"          \
    --compset=$compset                      \
    --machine=$machine                      \
    --cesm-create-newcase=$cesm_create_newcase \
    --cesm-env=$cesm_env                    \
    --user-namelist-dir=$user_namelist_dir  \
    --vt-scheme=$vt_scheme                  \
    --ocn-ncpu=$ocn_ncpu                    \
    --qflux-file=$qflux_file                \
    --seaice-file=$seaice_file              \
    --ocn-branch=$ocn_branch                \
    --single-job=$single_job

    
echo "$casename"
