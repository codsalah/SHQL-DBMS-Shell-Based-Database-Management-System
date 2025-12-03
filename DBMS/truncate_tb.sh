#!/usr/bin/bash

# Source YAD utility functions
source "$(dirname "$0")/yad_utilities.sh"

tableName=$1

# Ask for the table name 
if [ -z "$tableName" ]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        # In GUI mode, show list of available tables
        files=$(ls -p 2>/dev/null | grep -v / | grep -v "\.meta$")
        
        if [[ -z "$files" ]]; then
            show_info_dialog "No Tables" "No tables available in this database."
            exit 0
        fi
        
        # Build table options for show_options
        table_options=()
        while IFS= read -r table; do
            if [[ -n "$table" ]]; then
                table_options+=("database" "$table" "Table")
            fi
        done <<< "$files"
        
        if [ ${#table_options[@]} -eq 0 ]; then
            show_info_dialog "No Tables" "No tables available in this database."
            exit 0
        fi
        
        tableName=$(show_options "Truncate Table" "Choose a table to truncate:" "${table_options[@]}")
        if [ $? -ne 0 ] || [ -z "$tableName" ]; then
            exit 0
        fi
    else
        read -p "Enter table name to truncate: " tableName
    fi
fi

# Trim leading spaces
tableName="${tableName#"${tableName%%[![:space:]]*}"}"

# Trim trailing spaces
tableName="${tableName%"${tableName##*[![:space:]]}"}"

# Check if empty name
if [[ -z "$tableName" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        show_error_dialog "Table name cannot be empty."
    else
        echo -e "\nTable name cannot be empty.\n"
    fi
    exit 1
fi

# Check if table exists
if [[ ! -f "$tableName" || ! -f "$tableName.meta" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        show_error_dialog "Table or Metadata for '$tableName' does not exist."
    else
        echo "Table or Metadata for '$tableName' does not exist."
    fi
    exit 1
fi

# Ask before deletion
if [ "$DBMS_MODE" = "gui" ]; then
    if ! show_question_dialog "Are you sure you want to truncate '$tableName'? All data will be removed."; then
        show_info_dialog "Cancelled" "Operation canceled."
        exit 0
    fi
else
    read -p "Are you sure you want to truncate '$tableName'? (y/n) " confirm
    confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')
    
    if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
        echo "Operation canceled."
        exit 0
    fi
fi

# Preserve the header (first line) and overwrite the file
head -n 1 "$tableName" > "$tableName.tmp" && mv "$tableName.tmp" "$tableName"

if [ "$DBMS_MODE" = "gui" ]; then
    show_info_dialog "Success" "Table '$tableName' truncated (all data removed)."
else
    echo "Table '$tableName' truncated (all data removed)."
fi
