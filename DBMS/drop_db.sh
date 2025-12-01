#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

drop_db_with_name() {
    local name="$1"

    # Trim leading spaces
    name="${name#"${name%%[![:space:]]*}"}"
    # Trim trailing spaces
    name="${name%"${name##*[![:space:]]}"}"

    # Check if empty name
    if [[ -z "$name" ]]; then
        echo -e "\nDatabase name cannot be empty.\n"
        return 1
    fi

    # Check if directory exists inside Databases
    if [[ ! -d "$Databases/$name" ]]; then
        echo -e "\nDrop canceled — database '$name' does not exist.\n"
        return 1
    fi

    # Confirm deletion
    read -p "Are you sure you want to delete '$name'? [y/N]: " ans

    # Convert to lowercase
    ans=$(echo "$ans" | tr 'A-Z' 'a-z')

    # Check for y or yes
    if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
        rm -r "$Databases/$name"
        echo -e "\nDatabase '$name' has been deleted.\n"
        return 0
    else
        echo -e "\nDeletion cancelled.\n"
        return 1
    fi
}

# non-interactive mode (from queries.sh)
if [[ -n "$1" ]]; then
    drop_db_with_name "$1"
    exit $?
fi

# interactive mode (from menu)
while true
do
    read -p "Enter the name of the database you want to drop: " name
    if drop_db_with_name "$name"; then
        break
    fi
done

