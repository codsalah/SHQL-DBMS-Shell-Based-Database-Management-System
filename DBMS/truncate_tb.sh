#!/usr/bin/bash

tableName=$1

# Ask for the table name 
if [ -z "$tableName" ]; then
    read -p "Enter table name to truncate: " tableName
fi


# Trim leading spaces
tableName="${tableName#"${tableName%%[![:space:]]*}"}"

# Trim trailing spaces
tableName="${tableName%"${tableName##*[![:space:]]}"}"

# Check if empty name
if [[ -z "$tableName" ]]; then
    echo -e "\nTable name cannot be empty.\n"
    exit 1
fi

# Check if table exists
if [[ ! -f "$tableName" || ! -f "$tableName.meta" ]]; then
    echo "Table or Metadata for '$tableName' does not exist."
    exit 1
fi

# Ask before deletion
read -p "Are you sure you want to truncate '$tableName'? (y/n) " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # Preserve the header (first line) and overwrite the file
    head -n 1 "$tableName" > "$tableName.tmp" && mv "$tableName.tmp" "$tableName"
    echo "Table '$tableName' truncated (all data removed)."
elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then 
    echo "Operation canceled."
    exit 0
else
    echo "Invalid input. Operation canceled."
    exit 0
fi
