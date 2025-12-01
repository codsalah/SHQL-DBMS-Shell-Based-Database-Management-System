#!/usr/bin/bash

# Prompt for table name if not provided
tableName="$1"
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

# Print table schema
echo -e "\nTable Schema:"
echo "-------------"
pk_col=""
pk_col_index=-1
col_names=()
col_types=()

# Print table schema (for debugging purposes)
for col in "${columns[@]}"; do
    # IFS = Internal Field Separator to split the column string into parts
    IFS=':' read -ra parts <<< "$col"
    col_name="${parts[0]}"
    col_type="${parts[1]}"
    is_pk="${parts[2]}"

    # Add column name and type to arrays
    col_names+=("$col_name")
    col_types+=("$col_type")

    # print if column is primary key then add it to the primary key column array
    if [[ "$is_pk" == "PK" ]]; then
        echo "  $col_name ($col_type) [PRIMARY KEY]"
        pk_col="$col_name"
        # Get the index of the primary key column
        pk_col_index=${#col_names[@]}
        # Decrement the index by 1
        ((pk_col_index--))
    else
        # Print the column name and type
        echo "  $col_name ($col_type)"
    fi
done

echo -e "\nEnter values for the new row:"
echo "-----------------------------"

# Loop through the columns and get the values for the new row
row_data=""
for i in "${!col_names[@]}"; do
    while true; do
        read -p "${col_names[$i]} (${col_types[$i]}): " value < /dev/tty
        
        # Check for empty value or NULL)
        if [[ -z "$value" ]]; then
            # If this is the primary key column, reject NULL
            if [[ $i -eq $pk_col_index ]]; then
                echo "PRIMARY KEY VIOLATION: Primary key '${col_names[$i]}' cannot be NULL."
                continue
            fi
        fi
        
        # Validate based on type
        if [[ "${col_types[$i]}" == "int" ]]; then
            if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                echo "Invalid input. Please enter an integer."
                continue
            fi
        fi
        
        # Check for primary key duplicate
        if [[ $i -eq $pk_col_index ]]; then
            # Skip the first line (header) and check if this PK value already exists
            # The PK is at column index $pk_col_index (0-based)
            duplicate_found=false
            while IFS='|' read -ra existing_row; do
                if [[ "${existing_row[$pk_col_index]}" == "$value" ]]; then
                    duplicate_found=true
                    break
                fi
            # Read the table file, skipping the header line
            done < <(tail -n +2 "$tableName")
            
            # If duplicate found, reject the value
            if [[ "$duplicate_found" == true ]]; then
                echo "PRIMARY KEY VIOLATION: Value '$value' already exists for primary key '${col_names[$i]}'."
                continue
            fi
        fi
        
        break
    done
    
    # Add the value to the row data (If it's the first column, don't add a pipe)
    if [[ $i -eq 0 ]]; then
        row_data="$value"
    else
        row_data="$row_data|$value"
    fi
done

# Append the row to the table file
echo "$row_data" >> "$tableName"

echo -e "\nRow inserted successfully into table '$tableName'!"
