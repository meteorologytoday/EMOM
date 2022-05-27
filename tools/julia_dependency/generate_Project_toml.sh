#!/bin/bash

output_project_toml_file_dir=../..

julia --project="$output_project_toml_file_dir" add_pkgs.jl
