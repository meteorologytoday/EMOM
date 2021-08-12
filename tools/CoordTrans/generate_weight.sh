#!/bin/bash

function filename {
    dir_name=$( dirname "$1" )
    file_name=$( basename "$1" )
    file_ext="${file_name##*.}"
    file_name="${file_name%.*}"

    echo "$file_name"
}



script_root_dir=$(dirname $0)

lopts=(
    s-file
    d-file
    output-dir
    s-mask-value
    d-mask-value
)

options=$(getopt -o '' --long $(printf "%s:," "${lopts[@]}") -- "$@")
[ $? -eq 0 ] || { 
    echo "Incorrect options provided"
    exit 1
}
eval set -- "$options"


while true; do
    for lopt in "${lopts[@]}"; do
        eval "if [ \"\$1\" == \"--$lopt\" ]; then shift; export ${lopt//-/_}=\"\$1\"; shift; break; fi"
    done

    if [ "$1" == -- ]; then
        shift;
        break;
    fi
done

echo "Received parameters: "
for lopt in "${lopts[@]}"; do
    llopt=${lopt//-/_}
    eval "echo \"- $llopt=\$$llopt\""
done


w_file_conserve2nd="${output_dir}/wgt.conserve2nd.nc"
w_file_bilinear="${output_dir}/wgt.bilinear.nc"
w_file_neareststod="${output_dir}/wgt.neareststod.nc"

if [ ! -d "$output_dir" ] || [ ! -f "$w_file_conserve2nd" ] || [ ! -f "$w_file_bilinear" ]; then

    echo "Going to generate weighting files..."

    mkdir -p "$output_dir"

    s_SCRIP="${output_dir}/SCRIP_$( filename $s_file ).nc"
    d_SCRIP="${output_dir}/SCRIP_$( filename $d_file ).nc"

    julia $script_root_dir/generate_SCRIP_format.jl \
        --input-file=${s_file}    \
        --output-file=${s_SCRIP}    \
        --center-lon=xc     \
        --center-lat=yc     \
        --corner-lon=xv     \
        --corner-lat=yv     \
        --mask-value=${s_mask_value}

    julia $script_root_dir/generate_SCRIP_format.jl \
        --input-file=${d_file}    \
        --output-file=${d_SCRIP}    \
        --center-lon=xc     \
        --center-lat=yc     \
        --corner-lon=xv     \
        --corner-lat=yv     \
        --mask-value=${d_mask_value}



    #ESMF_RegridWeightGen -s ${s_SCRIP} -d ${d_SCRIP} -m conserve2nd -w $w_file_conserve2nd --user_areas --check --ignore_unmapped
    ESMF_RegridWeightGen -s ${s_SCRIP} -d ${d_SCRIP} -m conserve2nd -w $w_file_conserve2nd --norm_type fracarea --user_areas --check --ignore_unmapped
    ESMF_RegridWeightGen -s ${s_SCRIP} -d ${d_SCRIP} -m bilinear    -w $w_file_bilinear    --norm_type fracarea --user_areas --check --ignore_unmapped
    ESMF_RegridWeightGen -s ${s_SCRIP} -d ${d_SCRIP} -m neareststod -w $w_file_neareststod --norm_type fracarea --user_areas --check


else

    echo "Files are already there. Not going to generate weighting files."

fi
    
echo "Program ends."
