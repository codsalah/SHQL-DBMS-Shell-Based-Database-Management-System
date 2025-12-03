#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

# Source YAD utility functions
source "./yad_utilities.sh"

drop_db_with_name() {
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

    # Check if directory exists inside Databases
    if [[ ! -d "$Databases/$name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Drop canceled — database '$name' does not exist."
        else
            echo -e "\nDrop canceled — database '$name' does not exist.\n"
        fi
        return 1
    fi

    # Confirm deletion
    if [ "$DBMS_MODE" = "gui" ]; then
        show_question_dialog "Are you sure you want to delete '$name'?"
        if [ $? -eq 0 ]; then
            ans="y"
        else
            ans="n"
        fi
    else
        read -p "Are you sure you want to delete '$name'? [y/N]: " ans
    fi

    # Convert to lowercase
    ans=$(echo "$ans" | tr 'A-Z' 'a-z')

    # Check for y or yes
    if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
        rm -r "$Databases/$name"
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Success" "Database '$name' has been deleted."
        else
            echo -e "\nDatabase '$name' has been deleted.\n"
        fi
        return 0
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Cancelled" "Deletion cancelled."
        else
            echo -e "\nDeletion cancelled.\n"
        fi
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
    if [ "$DBMS_MODE" = "gui" ]; then
        # Build options list for GUI selection
        db_options=()
        for db in "$Databases"/*; do
            if [[ -d "$db" ]]; then
                db_name=$(basename "$db")
                db_options+=("database" "$db_name" "Database")
            fi
        done
        
        if [ ${#db_options[@]} -eq 0 ]; then
            show_info_dialog "Drop Database" "No databases available to drop."
            break
        fi

        name=$(show_options "Drop Database" "Select a database to drop:" "${db_options[@]}")
        if [ $? -ne 0 ] || [ -z "$name" ]; then
            break
        fi
    else
        read -p "Enter the name of the database you want to drop: " name
    fi

    if drop_db_with_name "$name"; then
        break
    fi
done

