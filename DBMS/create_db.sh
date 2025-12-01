#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

create_db_with_name() {
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

    # Check invalid characters
    if [[ "$name" =~ [^a-zA-Z0-9_] ]]; then
        echo -e "\nINVALID NAME!! Use only letters, numbers, and underscores.\n"
        return 1
    fi

    # Check starts with letter
    if [[ ! "$name" =~ ^[a-zA-Z] ]]; then
        echo -e "\nINVALID NAME!! Start the database name with a letter.\n"
        return 1
    fi

    # Check if directory exists inside Databases
    if [[ -d "$Databases/$name" ]]; then
        echo -e "\nDatabase '$name' already exists.\n"
        return 1
    fi

    # Create the database
    mkdir "$Databases/$name"
    echo -e "\nDatabase '$name' created successfully.\n"
    return 0
}

# non-interactive mode (from queries.sh)
if [[ -n "$1" ]]; then
    create_db_with_name "$1"
    exit $?
fi

# interactive mode (from menu)
while true
do
    read -p "Enter database name: " name
    if create_db_with_name "$name"; then
        break
    fi
done

