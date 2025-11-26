#!/usr/bin/bash

# Get Parent Path
ProjectPath="$(dirname "$PWD")"

# Databases directory
Databases="$ProjectPath/Databases"

# Ensure Databases folder exists
mkdir -p "$Databases"

# Count how many directories are inside
count=$(ls -A "$Databases" | wc -l)

if [[ $count -eq 0 ]]; then
    echo -e "\nYou don't have any databases yet.\n"
else
    echo -e "\n=========================================================================================="
    echo "                                         Databases                                         "
    echo -e "==========================================================================================\n"
    
    # List only directories
    for db in "$Databases"/*; do
        [[ -d "$db" ]] && echo " - $(basename "$db")"
    done
fi

