#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

# Source YAD utility functions
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/yad_utilities.sh"

drop_tb_with_name() {
    local name="$1"
    
    # Trim leading spaces
    name="${name#"${name%%[![:space:]]*}"}"
    # Trim trailing spaces
    name="${name%"${name##*[![:space:]]}"}"
    
    # Check if empty name
    if [[ -z "$name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Table name cannot be empty."
        else
            echo -e "\nTable name cannot be empty.\n"
        fi
        return 1
    fi
    
    # Check if table name ends with .meta
    if [[ "$name" == *.meta ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Table name cannot end with .meta."
        else
            echo -e "\nTable name cannot end with .meta.\n"
        fi
        return 1
    fi
    
    # Check if table exists
    if [[ ! -f "./$name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Drop canceled — table '$name' does not exist."
        else
            echo -e "\nDrop canceled — table '$name' does not exist.\n"
        fi
        return 1
    fi
    
    # Confirm deletion
    if [ "$DBMS_MODE" = "gui" ]; then
        show_question_dialog "Are you sure you want to delete table '$name'?"
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
        rm "./$name"
        rm "./$name.meta"
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Success" "Table '$name' has been deleted."
        else
            echo -e "\nTable '$name' has been deleted.\n"
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
    drop_tb_with_name "$1"
    exit $?
fi

# interactive mode (from menu)
attempt=0
tableName=""

while true
do
    # Ask for table name to drop if not provided
    if [[ -z "$tableName" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            # Build options list for GUI selection
            tb_options=()
            for tb in ./*; do
                # Skip if not a file
                if [[ ! -f "$tb" ]]; then
                    continue
                fi
                
                # Get filename without path
                tb_name=$(basename "$tb")
                
                # Skip .meta files
                if [[ "$tb_name" == *.meta ]]; then
                    continue
                fi
                
                # Skip hidden files and system files
                if [[ "$tb_name" == .* ]]; then
                    continue
                fi
                
                tb_options+=("text-x-generic" "$tb_name" "Table")
            done
            
            if [ ${#tb_options[@]} -eq 0 ]; then
                show_info_dialog "Drop Table" "No tables available to drop."
                break
            fi
            
            tableName=$(show_options "Drop Table" "Select a table to drop:" "${tb_options[@]}")
            if [ $? -ne 0 ] || [ -z "$tableName" ]; then
                break
            fi
        else
            read -p "Enter the name of the table you want to drop (or 'exit' to return): " tableName
        fi
    fi
    
    # Trim leading spaces
    tableName="${tableName#"${tableName%%[![:space:]]*}"}"
    # Trim trailing spaces
    tableName="${tableName%"${tableName##*[![:space:]]}"}"
    
    # Check if user wants to exit (CLI mode only)
    if [[ "$tableName" == "exit" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            # In GUI mode, treat as regular input
            :
        else
            echo -e "\nExiting drop table menu.\n"
            break
        fi
    fi
    
    # Try to drop the table
    if drop_tb_with_name "$tableName"; then
        break
    else
        ((attempt++))
        if [[ $attempt -ge 3 ]]; then
            if [ "$DBMS_MODE" = "gui" ]; then
                show_error_dialog "Invalid table name entered 3 times. Returning to menu."
            else
                echo -e "\nInvalid table name entered 3 times. Returning to menu.\n"
            fi
            break
        fi
        tableName=""
    fi
done
