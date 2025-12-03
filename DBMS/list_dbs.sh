#!/usr/bin/bash

# Get Parent Path
ProjectPath="$(dirname "$PWD")"

# Databases directory
Databases="$ProjectPath/Databases"

# Ensure Databases folder exists
mkdir -p "$Databases"

# Count how many directories are inside
# Source YAD utility functions
source "./yad_utilities.sh"

# Count how many directories are inside
count=$(ls -A "$Databases" | wc -l)

if [ "$DBMS_MODE" = "gui" ]; then
    if [[ $count -eq 0 ]]; then
        show_info_dialog "List Databases" "You don't have any databases yet."
    else
        # Build list for display
        db_list=""
        for db in "$Databases"/*; do
            if [[ -d "$db" ]]; then
                db_list+="$(basename "$db")\n"
            fi
        done
        show_results "Databases" "$db_list"
    fi
else
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
fi

