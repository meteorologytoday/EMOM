#!/bin/bash

#wk_dir=$( dirname $0 )
script_coordtrans_dir=$wk_dir/../CoordTrans
tmp_dir=tmp

echo "wk_dir: $wk_dir"

source "$wk_dir/lib_filename.sh"

lopts=(
    output-dir
    label
    input-clim-T-file
    input-clim-S-file
    input-init-T-file
    input-init-S-file
    input-init-MLD-file
    input-topo-file
    output-clim-T-file
    output-clim-S-file
    output-init-T-file
    output-init-S-file
    output-init-MLD-file
    output-topo-file
    old-domain-file
    new-domain-file
    T-unit
    output-zdomain-file
    output-resolution
)

source $wk_dir/getopt_helper.sh

mkdir -p $output_dir
mkdir -p $tmp_dir

# Make z-coordinate file for input coordinate
input_zdomain_file=$output_dir/input_zdomain.nc
ncks -O -v z_t $input_clim_T_file $input_zdomain_file
ncap2 -O -s 'zs=-z_t/100.0;' $input_zdomain_file $input_zdomain_file
ncatted -a units,zs,m,c,"meter"                                              \
        -a long_name,zs,m,c,"z-coordinate from surface to midpoint of layer" \
        $input_zdomain_file

# Make z-coordinate file for output coordinate
if [ ! -f $output_zdomain_file ]; then
    julia $script_coordtrans_dir/mk_HOOM_zdomain.jl \
        --output-file=$output_zdomain_file          \
        --resolution=$output_resolution
fi




# Generate correct transformed  coordinate files
if [ "$old_domain_file" == "$new_domain_file" ]; then
    wgt_file="X"
else
    wgt_file=$( basename $old_domain_file ".nc" )_$( basename $new_domain_file ".nc" ).nc
    
    wgt_dir="wgt_$( filename $old_domain_file )_to_$( filename $new_domain_file )"
    $script_coordtrans_dir/generate_weight.sh    \
        --s-file=$old_domain_file                \
        --d-file=$new_domain_file                \
        --output-dir="$wgt_dir"                  \
        --s-mask-value=1.0                       \
        --d-mask-value=1.0

fi



# Convert 3D variable: TEMP, SALT
data_files=(
    TEMP $input_clim_T_file $output_clim_T_file
    SALT $input_clim_S_file $output_clim_S_file
)
#    TEMP $input_init_T_file $output_init_T_file
#    SALT $input_init_S_file $output_init_S_file

for i in $( seq 1 $(( ${#data_files[@]} / 3))); do
    varname=${data_files[$((3*(i-1)))]}
    data_file=${data_files[$((3*(i-1)+1))]}
    new_data_file=${data_files[$((3*(i-1)+2))]}

    echo "[$varname] $data_file => $new_data_file"

    tmp1=$tmp_dir/${label}_$( basename $data_file ".nc" ).clim.nc
    tmp2=$tmp_dir/${label}_${resolution}_$( basename $data_file ".nc" ).new-domain.nc

    if [ ! -f $new_data_file ]; then
        
        echo "Transforming variable: $varname"
        
        ncwa -O -a time $data_file $tmp1
        ncks -O -3 $tmp1 $tmp1
        ncrename -d .nlat,Ny -d .nlon,Nx -d .z_t,Nz -d .ni,Nx -d .nj,Ny $tmp1
        ncks -O -4 $tmp1 $tmp1

        # Horizontal resolution
        if [ "$wgt_file" != "X" ]; then
            julia $script_coordtrans_dir/transform_data.jl --s-file=$tmp1 --d-file=$tmp2 --w-file=${wgt_dir}/wgt.neareststod.nc --vars=$varname --x-dim=Nx --y-dim=Ny --z-dim=Nz --algo=ESMF
        else
            mv $tmp1 $tmp2
        fi

        julia $script_coordtrans_dir/convert_z.jl           \
            --input-file=$tmp2                              \
            --input-zdomain-file=$input_zdomain_file        \
            --input-zdomain-varname=zs                      \
            --output-file=$new_data_file                    \
            --output-zdomain-file=$output_zdomain_file      \
            --output-zdomain-varname=zs                     \
            --input-zdomain-type=midpoints                  \
            --varname=$varname
            
        
#        rm -f $tmp1 $tmp2
    fi
done


# Convert 2D variable: MLD, TOPO
data_files=(
    depth  $input_topo_file $output_topo_file
)
#HMXL   $input_init_MLD_file $output_init_MLD_file

for i in $( seq 1 $(( ${#data_files[@]} / 3))); do
    varname=${data_files[$((3*(i-1)))]}
    data_file=${data_files[$((3*(i-1)+1))]}
    new_data_file=${data_files[$((3*(i-1)+2))]}

    tmp=$tmp_dir/${label}_$( basename ${data_file} ".nc" ).tmp.nc
    if [ ! -f "$new_data_file" ]; then

        echo "Transforming variable: $varname"

        ncks -O -3 $data_file $tmp
        ncrename -d .nlat,Ny -d .nlon,Nx -d .z_t,Nz -d .ni,Nx -d .nj,Ny $tmp
        ncks -O -4 $tmp $tmp
     

        if [ "$wgt_file" != "X" ]; then
            julia $script_coordtrans_dir/transform_data.jl \
                --s-file=$tmp \
                --d-file=$new_data_file \
                --w-file=${wgt_dir}/wgt.neareststod.nc \
                --vars=$varname \
                --x-dim=Nx \
                --y-dim=Ny \
                --algo=ESMF
        else
            mv $tmp $new_data_file
        fi
    fi
done



