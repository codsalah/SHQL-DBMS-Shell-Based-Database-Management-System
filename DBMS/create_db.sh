#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

# Source YAD utility functions
source "./yad_utilities.sh"

create_db_with_name() {
    local name="$1"

    # Trim leading spaces
    name="${name#"${name%%[![:space:]]*}"}"
    # Trim trailing spaces
    name="${name%"${name##*[![:space:]]}"}"

    # Check if empty name
    if [[ -z "$name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Database name cannot be empty."
        else
            echo -e "\nDatabase name cannot be empty.\n"
        fi
        return 1
    fi

    # Check invalid characters
    if [[ "$name" =~ [^a-zA-Z0-9_] ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "INVALID NAME!! Use only letters, numbers, and underscores."
        else
            echo -e "\nINVALID NAME!! Use only letters, numbers, and underscores.\n"
        fi
        return 1
    fi

    # Check starts with letter
    if [[ ! "$name" =~ ^[a-zA-Z] ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "INVALID NAME!! Start the database name with a letter."
        else
            echo -e "\nINVALID NAME!! Start the database name with a letter.\n"
        fi
        return 1
    fi

    # Check if directory exists inside Databases
    if [[ -d "$Databases/$name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Database '$name' already exists."
        else
            echo -e "\nDatabase '$name' already exists.\n"
        fi
        return 1
    fi

    # Create the database
    mkdir "$Databases/$name"
    if [ "$DBMS_MODE" = "gui" ]; then
        show_info_dialog "Success" "Database '$name' created successfully."
    else
        echo -e "\nDatabase '$name' created successfully.\n"
    fi
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
    if [ "$DBMS_MODE" = "gui" ]; then
        name=$(show_entry_dialog "Create Database" "Enter database name:" "")
        if [ $? -ne 0 ]; then break; fi
    else
        read -p "Enter database name: " name
    fi

    if create_db_with_name "$name"; then
        break
    fi
done

