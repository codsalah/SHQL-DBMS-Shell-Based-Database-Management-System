#!/usr/bin/bash

# Source YAD utility functions
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/yad_utilities.sh"

# First argument is table name, the rest (if any) are values
tableName="$1"
shift
values=("$@")   # may be empty (interactive mode) or full row (non-interactive)

# Prompt for table name only if not provided
if [[ -z "$tableName" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        # Build options list for GUI selection
        tb_options=()
        for tb in ./*; do
            if [[ ! -f "$tb" ]]; then
                continue
            fi
            
            tb_name=$(basename "$tb")
            
            if [[ "$tb_name" == *.meta ]]; then
                continue
            fi
            
            if [[ "$tb_name" == .* ]]; then
                continue
            fi
            
            tb_options+=("text-x-generic" "$tb_name" "Table")
        done
        
        if [ ${#tb_options[@]} -eq 0 ]; then
            show_info_dialog "Insert into Table" "No tables available."
            exit 0
        fi
        
        tableName=$(show_options "Insert into Table" "Select a table:" "${tb_options[@]}")
        if [ $? -ne 0 ] || [ -z "$tableName" ]; then
            exit 0
        fi
    else
        read -p "Enter table name: " tableName < /dev/tty
    fi
fi

# Trim leading and trailing spaces
tableName="${tableName#"${tableName%%[![:space:]]*}"}"
tableName="${tableName%"${tableName##*[![:space:]]}"}"

# Check if empty
if [[ -z "$tableName" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        show_error_dialog "Table name cannot be empty."
    else
        echo "Table name cannot be empty."
    fi
    exit 1
fi

# Check if table exists
if [[ ! -f "$tableName" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        show_error_dialog "Table '$tableName' does not exist."
    else
        echo "Table '$tableName' does not exist."
    fi
    exit 1
fi

# Check if metadata file exists
if [[ ! -f "$tableName.meta" ]]; then
    if [ "$DBMS_MODE" = "gui" ]; then
        show_error_dialog "Table metadata file '$tableName.meta' not found."
    else
        echo "Table metadata file '$tableName.meta' not found."
    fi
    exit 1
fi

# Read metadata to get column information
metadata=$(cat "$tableName.meta")

# Parse the metadata: format is "col1:type1:PK|col2:type2|col3:type3"
IFS='|' read -ra columns <<< "$metadata"

if [ "$DBMS_MODE" != "gui" ]; then
    echo -e "\nTable Schema:"
    echo "-------------"
fi

pk_col=""
pk_col_index=-1
col_names=()
col_types=()

# Build schema info text for GUI
schema_text=""

# Build column arrays and PK info
for col in "${columns[@]}"; do
    IFS=':' read -ra parts <<< "$col"
    col_name="${parts[0]}"
    col_type="${parts[1]}"
    is_pk="${parts[2]}"

    col_names+=("$col_name")
    col_types+=("$col_type")

    if [[ "$is_pk" == "PK" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            schema_text="${schema_text}${col_name} (${col_type}) [PRIMARY KEY]\n"
        else
            echo "  $col_name ($col_type) [PRIMARY KEY]"
        fi
        pk_col="$col_name"
        pk_col_index=${#col_names[@]}
        ((pk_col_index--))   # convert to 0-based
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            schema_text="${schema_text}${col_name} (${col_type})\n"
        else
            echo "  $col_name ($col_type)"
        fi
    fi
done

# Show schema in GUI mode
if [ "$DBMS_MODE" = "gui" ]; then
    show_info_dialog "Table Schema: $tableName" "$schema_text"
fi

# Decide if we are in non-interactive mode (values passed as args)
non_interactive=0
if (( ${#values[@]} > 0 )); then
    non_interactive=1
    if (( ${#values[@]} != ${#col_names[@]} )); then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Error: expected ${#col_names[@]} values but got ${#values[@]}."
        else
            echo "Error: expected ${#col_names[@]} values but got ${#values[@]}."
        fi
        exit 1
    fi
fi

if [ "$DBMS_MODE" != "gui" ]; then
    echo -e "\n${non_interactive==1 ? "Inserting provided values:" : "Enter values for the new row:"}"
    echo "-----------------------------"
fi

row_data=""

# Loop through the columns and get/validate values
for i in "${!col_names[@]}"; do
    while true; do
        if (( non_interactive )); then
            value="${values[$i]}"
        else
            if [ "$DBMS_MODE" = "gui" ]; then
                # Build prompt with column info
                pk_marker=""
                if [[ $i -eq $pk_col_index ]]; then
                    pk_marker=" [PRIMARY KEY]"
                fi
                
                value=$(show_entry_dialog "Insert into $tableName" "Enter value for:\n${col_names[$i]} (${col_types[$i]})${pk_marker}" "")
                if [ $? -ne 0 ]; then
                    exit 0
                fi
            else
                read -p "${col_names[$i]} (${col_types[$i]}): " value < /dev/tty
            fi
        fi

        # Trim spaces
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # Treat literal NULL as empty
        if [[ "$value" == "NULL" ]]; then
            value=""
        fi

        # Check for empty value on PK
        if [[ -z "$value" && $i -eq $pk_col_index ]]; then
            if [ "$DBMS_MODE" = "gui" ]; then
                show_error_dialog "PRIMARY KEY VIOLATION: Primary key '${col_names[$i]}' cannot be NULL."
            else
                echo "PRIMARY KEY VIOLATION: Primary key '${col_names[$i]}' cannot be NULL."
            fi
            if (( non_interactive )); then
                exit 1
            else
                continue
            fi
        fi

        # Validate based on type (int)
        if [[ -n "$value" && "${col_types[$i]}" == "int" ]]; then
            if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                if [ "$DBMS_MODE" = "gui" ]; then
                    show_error_dialog "Invalid input for ${col_names[$i]}. Please enter an integer."
                else
                    echo "Invalid input for ${col_names[$i]}. Please enter an integer."
                fi
                if (( non_interactive )); then
                    exit 1
                else
                    continue
                fi
            fi
        fi

        # Check for primary key duplicate
        if [[ $i -eq $pk_col_index && -n "$value" ]]; then
            duplicate_found=false
            while IFS='|' read -ra existing_row; do
                if [[ "${existing_row[$pk_col_index]}" == "$value" ]]; then
                    duplicate_found=true
                    break
                fi
            done < <(tail -n +2 "$tableName")

            if [[ "$duplicate_found" == true ]]; then
                if [ "$DBMS_MODE" = "gui" ]; then
                    show_error_dialog "PRIMARY KEY VIOLATION: Value '$value' already exists for primary key '${col_names[$i]}'."
                else
                    echo "PRIMARY KEY VIOLATION: Value '$value' already exists for primary key '${col_names[$i]}'."
                fi
                if (( non_interactive )); then
                    exit 1
                else
                    continue
                fi
            fi
        fi

        break
    done

    # Build row_data with | between columns
    if [[ $i -eq 0 ]]; then
        row_data="$value"
    else
        row_data="$row_data|$value"
    fi
done

# Append the row to the table file
echo "$row_data" >> "$tableName"

if [ "$DBMS_MODE" = "gui" ]; then
    show_info_dialog "Success" "Row inserted successfully into table '$tableName'!"
else
    echo -e "\nRow inserted successfully into table '$tableName'!"
fi
