#!/usr/bin/bash

read -p "Do you want to list tables with its metadata? (y/n): " list_metadata

# Convert input to lowercase for easier comparison
input=$(echo "$list_metadata" | tr '[:upper:]' '[:lower:]')

echo -e "\nExisting Tables:"
echo "----------------"

# List files in current directory, excluding subdirectories
files=$(ls -p | grep -v /)

# only accept yes or y as input 
if [[ "$input" == "y" || "$input" == "yes" ]]; then
    # Show all files (tables and metadata)
    tables="$files"
# only accept n or no as input  
elif [[ "$input" == "n" || "$input" == "no" ]]; then
    # Exclude .meta files if no
    tables=$(echo "$files" | grep -v "\.meta$")
else
    echo "Invalid input. Only 'y/yes' or 'n/no' are accepted."
    exit 1
fi

if [[ -z "$tables" ]]; then
    echo "No tables found."
else
    echo "$tables"
fi
echo "----------------"
