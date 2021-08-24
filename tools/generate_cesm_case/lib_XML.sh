#!/bin/bash

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
