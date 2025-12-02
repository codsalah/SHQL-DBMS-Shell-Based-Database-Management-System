#!/usr/bin/bash

# Function to get column index
get_col_index() {
    local table=$1
    local col_name=$2
    local header_line=$(head -n 1 "$table")

    IFS='|' read -r -a headers <<< "$header_line"

    for i in "${!headers[@]}"; do
        if [[ "${headers[$i]}" == "$col_name" ]]; then
            echo $((i + 1))
            return
        fi
    done
    echo -1
}

# Function to print table (with or without column command)
print_table() {
    if command -v column &> /dev/null; then
        column -t -s '|'  # Use column for formatting, aligning the columns
    else
        cat
    fi
}

# Select all rows from the table
select_all() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    
    # Extract table name from the full path
    table_name=$(basename "$table")
    
    echo -e "\n--- Table: $table_name ---"
    print_table < "$table"
}

# Select specific columns from the table
select_specific_columns() {
    local table=$1
    local columns=$2  # Column names passed from the query
    
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    
    # Extract table name from the full path
    table_name=$(basename "$table")

    # Print the table name, not the full path
    echo -e "\n--- Table: $table_name ---"

    # Read the header line from the table (the first row)
    header_line=$(head -n 1 "$table")

    # Convert column names into an array (separated by spaces)
    IFS=' ' read -r -a cols_array <<< "$columns"

    local indices=""
    for col in "${cols_array[@]}"; do
        idx=$(get_col_index "$table" "$col")
        if [[ $idx -eq -1 ]]; then
            echo "Column '$col' not found."
            return
        fi
        if [[ -z "$indices" ]]; then
            indices="$idx"
        else
            indices="$indices,$idx"
        fi
    done

    # Extract the selected columns using 'cut' and format with 'column' to align
    cut -d '|' -f "$indices" "$table" | print_table
}

# Select by primary key
select_by_pk() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi

    read -p "Enter PK value: " searchTarget
    if [[ -z "$searchTarget" ]]; then
        echo "No search target provided."
        return
    fi

    if [[ ! -f "$table.meta" ]]; then
        echo "Metadata not found."
        return
    fi

    local metadata=$(cat "$table.meta")
    IFS='|' read -ra columns <<< "$metadata"

    local pkIndex=0
    local pkType=""
    local currentCol=1
    
    for col in "${columns[@]}"; do
        IFS=':' read -ra parts <<< "$col"
        if [[ "${parts[2]}" == "PK" ]]; then
            pkIndex=$currentCol
            pkType=${parts[1]}
            break
        fi
        ((currentCol++))
    done

    if [ $pkIndex -eq 0 ]; then
        echo "Error: No Primary Key found."
        return
    fi

    # Binary Search for PK (adjusted)
    local result=""
    while read -r line; do
        pkValue=$(echo "$line" | cut -d '|' -f "$pkIndex")
        if [[ "$pkValue" == "$searchTarget" ]]; then
            result="$line"
            break
        fi
    done < "$table"

    if [[ -n "$result" ]]; then
        (head -n 1 "$table"; echo "$result") | print_table
    else
        echo "Not Found"
    fi
}

# Function to handle numerical conditions
select_numerical_condition() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi

    read -p "Enter column name: " col
    local col_idx=$(get_col_index "$table" "$col")

    if [[ $col_idx -eq -1 ]]; then
        echo "Column '$col' not found."
        return
    fi

    read -p "Enter operator (==, !=, >, <, >=, <=): " op
    read -p "Enter value: " val

    # Check column type from metadata
    metadata=$(cat "$table.meta")
    IFS='|' read -ra columns <<< "$metadata"
    col_type=""
    for col in "${columns[@]}"; do
        IFS=':' read -ra parts <<< "$col"
        if [[ "${parts[0]}" == "$col" ]]; then
            col_type="${parts[1]}"
            break
        fi
    done

    # Validate operator
    if [[ ! "$op" =~ ^(==|!=|>|<|>=|<=)$ ]]; then
        echo "Invalid operator: $op"
        return
    fi

    (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" "NR > 1 && \$c $op v" "$table") | print_table
}

# Function to handle string conditions
select_string_condition() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi

    read -p "Enter column name: " col
    local col_idx=$(get_col_index "$table" "$col")

    if [[ $col_idx -eq -1 ]]; then
        echo "Column '$col' not found."
        return
    fi

    read -p "Enter LIKE pattern: " like_pattern

    # Check column type from metadata
    metadata=$(cat "$table.meta")
    IFS='|' read -ra columns <<< "$metadata"
    col_type=""
    for col in "${columns[@]}"; do
        IFS=':' read -ra parts <<< "$col"
        if [[ "${parts[0]}" == "$col" ]]; then
            col_type="${parts[1]}"
            break
        fi
    done

    # Convert LIKE pattern to regex
    local regex_pattern="${like_pattern//%/.*}"
    regex_pattern="${regex_pattern//_/.}"
    regex_pattern="^$regex_pattern$"

    (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v p="$regex_pattern" 'NR > 1 {val = $c; gsub(/^ +| +$/, "", val); if (val ~ p) print $0}' "$table") | print_table
}

# Main Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tableName="$1"
    while true; do
        if [[ -z "$tableName" ]]; then
            read -p "Enter table name: " tableName
        fi
        # Trim leading and trailing spaces
        tableName="${tableName#"${tableName%%[![:space:]]*}"}"
        tableName="${tableName%"${tableName##*[![:space:]]}"}"

        # Check if empty name, table does not exist, or metadata does not exist
        if [[ -z "$tableName" ]]; then
            echo "Table name cannot be empty."
            tableName=""
            continue
        fi
        if [[ ! -f "$tableName" ]]; then
            echo "Table $tableName does not exist."
            tableName=""
            continue
        fi
        if [[ ! -f "$tableName.meta" ]]; then
            echo "Metadata for $tableName does not exist."
            tableName=""
            continue
        fi
        
        break
    done

    PS3="Choose operation to select from table: "
    select choice in \
        "Select All" \
        "Select Specific Columns" \
        "Select Specific Row (PK)" \
        "Select Specific Row (Non-PK)" \
        "Select With Numerical Condition" \
        "Select With String Condition" \
        "Back"
    do
        case "$REPLY" in
            1) select_all "$tableName" ;;
            2) select_specific_columns "$tableName" ;;
            3) select_by_pk "$tableName" ;;
            4) select_normal_row "$tableName" ;;
            5) select_numerical_condition "$tableName" ;;
            6) select_string_condition "$tableName" ;;
            7) break ;;
            *) echo "Invalid choice" ;;
        esac
    done
fi

