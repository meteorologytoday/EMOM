#!/bin/bash

resolution="$1"

if [ "$resolution" = "" ] ; then

    echo "Error: Please provide the resolution."
    exit 1
    
fi

echo "Using the resolution: $resolution"

casename=CAM5_POP2_${resolution}
env_mach_pes_file=env_mach_pes_${resolution}.sh

machine=cheyenne
compset=B_1850_CAM5
user_namelist_dir=`pwd`/../shared_user_namelist
walltime="12:00:00"
PROJECT=UMIA0022
create_newcase=$HOME/ucar_models/cesm1_2_2_1_lw-nudging/scripts/create_newcase

# Need to pay extra attention: run with restart file coming from piControl seaice
env_run=(
    STOP_OPTION       nyears
    STOP_N            5
)


setXML() {
    local args=("$@")
    local filename=$1
    local settings=("${args[@]:1}")
    
    local n=$((${#settings[@]}/2))

    for i in $(seq 1 $((${#settings[@]}/2))); do
        local key=${settings[$((2*(i-1)))]}
        local val=${settings[$((2*(i-1)+1))]}
        printf "[%s] => [%s]\n" $key $val
        ./xmlchange -f $filename -id $key -val $val
    done
}

getXML() {
    local pairs=("$@")
    
    local n=$((${#pairs[@]}/2))

    for i in $(seq 1 $((${#pairs[@]}/2))); do
        local varname=${pairs[$((2*(i-1)))]}
        local id=${pairs[$((2*(i-1)+1))]}
        local val=$(./xmlquery $id -silent -valonly)
        printf "[%s] (%s) => [%s]\n" $varname $id $val
        eval "export $varname=\"$val\""
    done
}

source $env_mach_pes_file

wdir=$( pwd );

if [ -d $casename ]; then
    echo "Error: $casename already exists. Abort."
    exit 1;
fi


${create_newcase}         \
    -case      $casename    \
    -compset   $compset     \
    -res       $resolution  \
    -mach      $machine

if [ ! -d $casename ] ; then
    echo "Error: $casename is not properly created. Abort."
    exit 1;
fi


cd $casename

setXML "env_run.xml" "${env_run[@]}"
setXML "env_mach_pes.xml" "${env_mach_pes[@]}"
cp $wdir/POP2_SourceMods/* SourceMods/src.pop2/

# copy user namelist
if [ "$user_namelist_dir" != "" ]; then
    cp $user_namelist_dir/user_nl_* .
fi

# Must setup here to get calculated TOTALPES
./cesm_setup
