#!/usr/bin/bash

# Function to get column index
get_col_index() {
    # tableName, columnName, headerLine variables
    local table=$1
    local col_name=$2
    local header_line=$(head -n 1 "$table")

    # Read the header line into an array (headers)
    IFS='|' read -r -a headers <<< "$header_line"

    # Loop through the headers to find the colum index
    for i in "${!headers[@]}"; do
        if [[ "${headers[$i]}" == "$col_name" ]]; then
            echo $((i + 1))
            return
        fi
    done
    echo -1
}

print_table() {
    # Check if column command is available
    if command -v column &> /dev/null; then
        # Use column to format the table
        column -t -s '|'
    else
        cat
    fi
}

select_all() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    echo -e "\n--- Table: $table ---"
    print_table < "$table"
}

select_specific_columns() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    # Print the column names first 
    echo -e "\n--- Table: $table ---"
    head -n 1 "$table"

    read -p "Enter columns (comma separated): " cols_input
    
    if [[ -z "$cols_input" ]]; then
        echo "No columns specified."
        return
    fi

    # Replace comma with space to allow both separators
    local cols_space_separated="${cols_input//,/ }"
    
    # Read the columns into an array (cols_array)
    IFS=' ' read -r -a cols_array <<< "$cols_space_separated"
    
    local indices=""
    # Get indices of specified columns (@ is the array)
    for col in "${cols_array[@]}"; do
        # Get the index of the column
        idx=$(get_col_index "$table" "$col")
        # Check if column exists first 
        if [[ $idx -eq -1 ]]; then
            echo "Column '$col' not found."
            return
        fi
        # Add index to the list (indeces like 1,2,3)
        if [[ -z "$indices" ]]; then
            indices="$idx"
        else
            indices="$indices,$idx"
        fi
    done
    # Now we can use cut to select specific columns
    cut -d '|' -f "$indices" "$table" | print_table
}

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

    # Metadata check
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

    # Sort Logic (adapted from sort_index_search.sh)
    local headerFile="${table}.header"
    local bodyFile="${table}.body"
    local sortedBodyFile="${table}.sorted_body"
    
    head -n 1 "$table" > "$headerFile"
    local headerContent=$(cat "$headerFile")
    tail -n +2 "$table" | grep -vF "$headerContent" > "$bodyFile"
    
    if [ "$pkType" == "int" ]; then
        sort -t '|' -k"${pkIndex},${pkIndex}n" "$bodyFile" > "$sortedBodyFile"
    else
        sort -t '|' -k"${pkIndex},${pkIndex}" "$bodyFile" > "$sortedBodyFile"
    fi
    
    cat "$headerFile" "$sortedBodyFile" > "$table"
    rm "$headerFile" "$bodyFile" "$sortedBodyFile"

    # Binary Search (Repeated logic from sort_index_search.sh)
    local totalLines=$(wc -l < "$table")
    local numRows=$((totalLines - 1))
    local low=0
    local high=$((numRows - 1))
    local mid
    local lineNum
    local row
    local midVal
    

    local found=0
    local result=""

    while [ $low -le $high ]; do
        mid=$(( (low + high) / 2 ))
        lineNum=$((mid + 2))
        
        row=$(sed -n "${lineNum}p" "$table")
        midVal=$(echo "$row" | cut -d '|' -f "$pkIndex")
        
        if [ "$midVal" == "$searchTarget" ]; then
            result="$row"
            found=1
            break
        fi
        
        if [ "$pkType" == "int" ]; then
            if ! [[ "$searchTarget" =~ ^[0-9]+$ ]]; then
                echo "Target must be integer."
                return 1
            fi
            if [ "$midVal" -lt "$searchTarget" ]; then
                low=$((mid + 1))
            else
                high=$((mid - 1))
            fi
        else
            if [[ "$midVal" < "$searchTarget" ]]; then
                low=$((mid + 1))
            else
                high=$((mid - 1))
            fi
        fi
    done

    if [[ $found -eq 1 ]]; then
        (head -n 1 "$table"; echo "$result") | print_table
    else
        echo "Not Found"
    fi
}


select_normal_row() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    # Print the column names first 
    echo -e "\n--- Table: $table ---"
    head -n 1 "$table"


    read -p "Enter column name: " col
    
    
    local col_idx=$(get_col_index "$table" "$col")

    # Check if column exists
    if [[ $col_idx -eq -1 ]]; then
        echo "Column '$col' not found."
        return
    fi

    read -p "Enter value: " val
    
    # head -n 1 "$table" to print the header then awk to print the rows that match the condition
    # -F'|' sets the field separator to |.
    # NR > 1 skips the header row.
    # $c == v performs the equality comparison ---------------------------->.
    (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" 'NR > 1 && $c == v' "$table") | print_table
}

select_numerical_condition() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    read -p "Enter column name: " col
    
    local col_idx=$(get_col_index "$table" "$col")
    # Check if column exists
    if [[ $col_idx -eq -1 ]]; then
        echo "Column '$col' not found."
        return
    fi

    read -p "Enter operator (==, !=, >, <, >=, <=): " op
    read -p "Enter value: " val
    
    # Validate operator
    if [[ ! "$op" =~ ^(==|!=|>|<|>=|<=)$ ]]; then
        echo "Invalid operator: $op"
        return
    fi

    # head -n 1 "$table" to print the header then awk to print the rows that match the condition
    

    #-F'|' sets the field separator to |.
    #NR > 1 skips the header row.
    #$c $op v performs the numeric comparison.
    # Pipe it out to print_table function
    (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" "NR > 1 && \$c $op v" "$table") | print_table
}

# SQL LIKE pattern matching
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

    echo "Enter LIKE pattern (use % and _ only):"
    read -p "Pattern: " like_pattern

    # Replace '%' with '.*' (Matches any sequence of characters)
    local regex_pattern="${like_pattern//%/.*}"
    
    # Replace '_' with '.' (Matches exactly one character)
    regex_pattern="${regex_pattern//_/.}"
    
    # Add anchors to match the whole string
    regex_pattern="^$regex_pattern$"

    (
        head -n 1 "$table"
        awk -F'|' -v c="$col_idx" -v p="$regex_pattern" '
            NR > 1 {
                val = $c
                gsub(/^ +| +$/, "", val);   # trim spaces just for comparison
                if (val ~ p) print $0;
            }
        ' "$table"
    ) | print_table
}


# Main Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        read -p "Enter table name: " tableName
        # Trim leading and trailing spaces
        tableName="${tableName#"${tableName%%[![:space:]]*}"}"
        tableName="${tableName%"${tableName##*[![:space:]]}"}"

        # Check if empty name, table does not exist, or metadata does not exist
        [[ -z "$tableName" ]] && echo "Table name cannot be empty." && continue
        [[ ! -f "$tableName" ]] && echo "Table $tableName does not exist." && continue
        [[ ! -f "$tableName.meta" ]] && echo "Metadata for $tableName does not exist." && continue
        
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
