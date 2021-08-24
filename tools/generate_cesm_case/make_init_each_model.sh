#!/bin/bash

#wk_dir=$( dirname $0 )
script_coordtrans_dir=$wk_dir/../CoordTrans
tmp_dir=tmp

echo "wk_dir: $wk_dir"

lopts=(
    output-file
    label
    data-clim-T-file
    data-clim-S-file
    domain-file
    zdomain-file
    topo-file
    T-unit
    S-unit
    vt-scheme
    hz-scheme
    relaxation-time
    forcing-file
)

source $wk_dir/getopt_helper.sh

gen_code="$wk_dir/init_code/HOOM_${vt_scheme}_${hz_scheme}/make_init.jl"
printf "[%s] => [%s] : [%s]\n" $vt_scheme $hz_scheme $relaxation_time $gen_code

if [ ! -f $output_file ]; then

    julia $gen_code               \
        --output-file=$output_file                  \
        --data-clim-T-file=$data_clim_T_file        \
        --data-clim-S-file=$data_clim_S_file        \
        --topo-file=$topo_file                      \
        --domain-file=$domain_file                  \
        --zdomain-file=$zdomain_file                \
        --T-unit=$T_unit                            \
        --S-unit=$S_unit                            \
        --forcing-file=$forcing_file                \
        --relaxation-time=$((86400 * 365 * $relaxation_time))

fi
