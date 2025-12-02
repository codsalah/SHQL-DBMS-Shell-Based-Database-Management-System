#!/usr/bin/bash

# First argument is table name, the rest (if any) are values
tableName="$1"
shift
values=("$@")   # may be empty (interactive mode) or full row (non-interactive)

# Prompt for table name only if not provided
if [[ -z "$tableName" ]]; then
    read -p "Enter table name: " tableName < /dev/tty
fi

# Trim leading and trailing spaces
tableName="${tableName#"${tableName%%[![:space:]]*}"}"
tableName="${tableName%"${tableName##*[![:space:]]}"}"

# Check if empty
if [[ -z "$tableName" ]]; then
    echo "Table name cannot be empty."
    exit 1
fi

# Check if table exists
if [[ ! -f "$tableName" ]]; then
    echo "Table '$tableName' does not exist."
    exit 1
fi

# Check if metadata file exists
if [[ ! -f "$tableName.meta" ]]; then
    echo "Table metadata file '$tableName.meta' not found."
    exit 1
fi

# Read metadata to get column information
metadata=$(cat "$tableName.meta")

# Parse the metadata: format is "col1:type1:PK|col2:type2|col3:type3"
IFS='|' read -ra columns <<< "$metadata"

echo -e "\nTable Schema:"
echo "-------------"
pk_col=""
pk_col_index=-1
col_names=()
col_types=()

# Build column arrays and PK info
for col in "${columns[@]}"; do
    IFS=':' read -ra parts <<< "$col"
    col_name="${parts[0]}"
    col_type="${parts[1]}"
    is_pk="${parts[2]}"

    col_names+=("$col_name")
    col_types+=("$col_type")

    if [[ "$is_pk" == "PK" ]]; then
        echo "  $col_name ($col_type) [PRIMARY KEY]"
        pk_col="$col_name"
        pk_col_index=${#col_names[@]}
        ((pk_col_index--))   # convert to 0-based
    else
        echo "  $col_name ($col_type)"
    fi
done

# Decide if we are in non-interactive mode (values passed as args)
non_interactive=0
if (( ${#values[@]} > 0 )); then
    non_interactive=1
    if (( ${#values[@]} != ${#col_names[@]} )); then
        echo "Error: expected ${#col_names[@]} values but got ${#values[@]}."
        exit 1
    fi
fi

echo -e "\n${non_interactive==1 ? "Inserting provided values:" : "Enter values for the new row:"}"
echo "-----------------------------"

row_data=""

# Loop through the columns and get/validate values
for i in "${!col_names[@]}"; do
    while true; do
        if (( non_interactive )); then
            value="${values[$i]}"
        else
            read -p "${col_names[$i]} (${col_types[$i]}): " value < /dev/tty
        fi

        # Treat literal NULL as empty
        if [[ "$value" == "NULL" ]]; then
            value=""
        fi

        # Check for empty value on PK
        if [[ -z "$value" && $i -eq $pk_col_index ]]; then
            echo "PRIMARY KEY VIOLATION: Primary key '${col_names[$i]}' cannot be NULL."
            if (( non_interactive )); then
                exit 1
            else
                continue
            fi
        fi

        # Validate based on type (int)
        if [[ -n "$value" && "${col_types[$i]}" == "int" ]]; then
            if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                echo "Invalid input for ${col_names[$i]}. Please enter an integer."
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
                echo "PRIMARY KEY VIOLATION: Value '$value' already exists for primary key '${col_names[$i]}'."
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

echo -e "\nRow inserted successfully into table '$tableName'!"

