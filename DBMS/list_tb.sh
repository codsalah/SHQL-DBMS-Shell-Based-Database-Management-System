#!/usr/bin/bash

# Source YAD utility functions
source "$(dirname "$0")/yad_utilities.sh"

# List files in current directory, excluding subdirectories
files=$(ls -p | grep -v /)

if [[ -z "$files" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        show_info_dialog "No Tables" "No existing tables in this database."
    else
        echo "-------------------"
        echo "No Existing Tables"
        echo "-------------------"
    fi
else
    # Check if argument is provided
    list_metadata="$1"
    if [[ -z "$list_metadata" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            if show_question_dialog "Do you want to list tables with metadata?"; then
                list_metadata="y"
            else
                ret=$?
                # If user clicked Cancel (return code 252) or closed dialog, exit gracefully
                if [ $ret -eq 252 ] || [ $ret -eq 1 ]; then
                    list_metadata="n"
                else
                    list_metadata="n"
                fi
            fi
        else
            read -p "Do you want to list tables with its metadata? (y/n): " list_metadata
        fi
    fi
    
    # Convert input to lowercase for easier comparison
    input=$(echo "$list_metadata" | tr '[:upper:]' '[:lower:]')
    
    # only accept yes or y as input 
    if [[ "$input" == "y" || "$input" == "yes" ]]; then
        # Show all files (tables and metadata)
        tables="$files"
        if [ "$DBMS_MODE" = "gui" ]; then
            show_results "Tables with Metadata" "$tables" 600 400
        else
            echo -e "\nExisting Tables with its metadata:"
            echo "----------------"
            echo $tables
            echo -e "-------------------\n"
        fi
    # only accept n or no as input  
    elif [[ "$input" == "n" || "$input" == "no" ]]; then
        # Exclude .meta files if no
        tables=$(echo "$files" | grep -v "\.meta$")
        if [ "$DBMS_MODE" = "gui" ]; then
            show_results "Tables" "$tables" 600 400
        else
            echo -e "\nExisting Tables:"
            echo "----------------"
            echo $tables
            echo -e "-------------------\n"
        fi
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Invalid input. Only 'y/yes' or 'n/no' are accepted."
        else
            echo "Invalid input. Only 'y/yes' or 'n/no' are accepted."
        fi
        exit 1
    fi
fi

