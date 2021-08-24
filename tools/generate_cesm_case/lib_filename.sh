#!/bin/bash

function filename {
    dir_name=$( dirname "$1" )
    file_name=$( basename "$1" )
    file_ext="${file_name##*.}"
    file_name="${file_name%.*}"

    echo "$file_name"
}


