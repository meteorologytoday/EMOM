#!/bin/bash

domain=gx3v7
echo "Domain is set as: $domain"

code_files=(
    03_create_init_ocn.sh
)


for code_file in "${code_files[@]}" ; do
    echo "Running $code_file"
    ./$code_file
done
