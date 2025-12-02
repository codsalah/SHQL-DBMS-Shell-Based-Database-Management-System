#!/usr/bin/bash

# List files in current directory, excluding subdirectories
files=$(ls -p | grep -v /)

if [[ -z "$files" ]]; then
    echo "-------------------"
    echo "No Existing Tables"
    echo "-------------------"
else
    # Check if argument is provided
    list_metadata="$1"
    if [[ -z "$list_metadata" ]]; then
        read -p "Do you want to list tables with its metadata? (y/n): " list_metadata
    fi
    # Convert input to lowercase for easier comparison
    input=$(echo "$list_metadata" | tr '[:upper:]' '[:lower:]')
    # only accept yes or y as input 
    if [[ "$input" == "y" || "$input" == "yes" ]]; then
        # Show all files (tables and metadata)
        echo -e "\nExisting Tables with its metadata:"
        echo "----------------"
        tables="$files"
        echo $tables
    # only accept n or no as input  
    elif [[ "$input" == "n" || "$input" == "no" ]]; then
        # Exclude .meta files if no
        echo -e "\nExisting Tables:"
        echo "----------------"
        tables=$(echo "$files" | grep -v "\.meta$")
        echo $tables
    else
        echo "Invalid input. Only 'y/yes' or 'n/no' are accepted."
        exit 1
    fi
fi
echo -e "-------------------\n"

