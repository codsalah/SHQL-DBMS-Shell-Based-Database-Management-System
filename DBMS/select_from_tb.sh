#!/usr/bin/bash

# Source YAD utilities if in GUI mode
if [ "$DBMS_MODE" = "gui" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/yad_utilities.sh"
fi

# Function to get column index
get_col_index() {
    local table=$1
    local col_name=$2
    local header_line=$(head -n 1 "$table")

    IFS='|' read -r -a headers <<< "$header_line"

    for i in "${!headers[@]}"; do
        # Trim whitespace from header
        local trimmed_header=$(echo "${headers[$i]}" | xargs)
        local trimmed_col=$(echo "$col_name" | xargs)
        if [[ "$trimmed_header" == "$trimmed_col" ]]; then
            echo $((i + 1))
            return
        fi
    done
    echo -1
}

# Function to print table (with or without column command)
print_table() {
    if command -v column &> /dev/null; then
        column -t -s '|'
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
    
    table_name=$(basename "$table")
    
    if [ "$DBMS_MODE" = "gui" ]; then
        # Read table data
        local table_data=$(cat "$table" | print_table)
        show_results "Table: $table_name" "$table_data" 800 500
    else
        echo -e "\n--- Table: $table_name ---"
        print_table < "$table"
    fi
}

# Select specific columns from the table
select_specific_columns() {
    local table=$1
    local columns=$2
    
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi
    
    table_name=$(basename "$table")

    header_line=$(head -n 1 "$table")

    IFS=' ' read -r -a cols_array <<< "$columns"

    local indices=""
    for col in "${cols_array[@]}"; do
        # Trim whitespace from column name
        col=$(echo "$col" | xargs)
        if [[ -z "$col" ]]; then
            continue
        fi
        
        idx=$(get_col_index "$table" "$col")
        if [[ $idx -eq -1 ]]; then
            if [ "$DBMS_MODE" = "gui" ]; then
                show_error_dialog "Column '$col' not found."
            else
                echo "Column '$col' not found."
            fi
            return
        fi
        if [[ -z "$indices" ]]; then
            indices="$idx"
        else
            indices="$indices,$idx"
        fi
    done

    if [ "$DBMS_MODE" = "gui" ]; then
        local result=$(cut -d '|' -f "$indices" "$table" | print_table)
        show_results "Table: $table_name (Selected Columns)" "$result" 800 500
    else
        echo -e "\n--- Table: $table_name ---"
        cut -d '|' -f "$indices" "$table" | print_table
    fi
}

# Select by primary key
select_by_pk() {
    local table=$1
    local searchTarget=$2
    
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi

    # If searchTarget is not provided, prompt for it
    if [[ -z "$searchTarget" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            searchTarget=$(show_entry_dialog "Select by PK" "Enter PK value:" "")
            if [ $? -ne 0 ] || [ -z "$searchTarget" ]; then
                return
            fi
        else
            read -p "Enter PK value: " searchTarget
            if [[ -z "$searchTarget" ]]; then
                echo "No search target provided."
                return
            fi
        fi
    fi

    if [[ ! -f "$table.meta" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Metadata not found."
        else
            echo "Metadata not found."
        fi
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
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "No Primary Key found."
        else
            echo "Error: No Primary Key found."
        fi
        return
    fi

    local result=""
    while read -r line; do
        pkValue=$(echo "$line" | cut -d '|' -f "$pkIndex")
        if [[ "$pkValue" == "$searchTarget" ]]; then
            result="$line"
            break
        fi
    done < "$table"

    if [[ -n "$result" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            local output=$((head -n 1 "$table"; echo "$result") | print_table)
            show_results "Found Row" "$output" 700 300
        else
            (head -n 1 "$table"; echo "$result") | print_table
        fi
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Not Found" "No row found with PK value '$searchTarget'"
        else
            echo "Not Found"
        fi
    fi
}

# NEW FUNCTION: Select with WHERE clause (handles all operators including LIKE)
select_where() {
    local table=$1
    local col=$2
    local op=$3
    local val=$4
    
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return 1
    fi
    
    # Get column index
    local col_idx=$(get_col_index "$table" "$col")
    
    if [[ $col_idx -eq -1 ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Column '$col' not found."
        else
            echo "Column '$col' not found."
        fi
        return 1
    fi
    
    table_name=$(basename "$table")
    
    # Handle LIKE operator specially
    if [[ "${op,,}" == "like" ]]; then
        # Convert SQL LIKE pattern to regex
        local regex_pattern="${val//%/.*}"
        regex_pattern="${regex_pattern//_/.}"
        regex_pattern="^${regex_pattern}$"
        
        if [ "$DBMS_MODE" = "gui" ]; then
            local output=$((head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v p="$regex_pattern" 'NR > 1 {val = $c; gsub(/^ +| +$/, "", val); if (val ~ p) print $0}' "$table") | print_table)
            show_results "Query Results: $table_name" "$output" 800 500
        else
            echo -e "\n--- Query Results: $table_name ---"
            (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v p="$regex_pattern" 'NR > 1 {val = $c; gsub(/^ +| +$/, "", val); if (val ~ p) print $0}' "$table") | print_table
        fi
        return 0
    fi
    
    # Validate operator for non-LIKE operations
    if [[ ! "$op" =~ ^(==|!=|>|<|>=|<=)$ ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Invalid operator: $op. Use: ==, !=, >, <, >=, <=, LIKE"
        else
            echo "Invalid operator: $op. Valid operators: ==, !=, >, <, >=, <=, LIKE"
        fi
        return 1
    fi
    
    # Check if value is numeric or string
    if [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        # Numeric comparison
        if [ "$DBMS_MODE" = "gui" ]; then
            local output=$((head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" "NR > 1 && \$c $op v" "$table") | print_table)
            show_results "Query Results: $table_name" "$output" 800 500
        else
            echo -e "\n--- Query Results: $table_name ---"
            (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" "NR > 1 && \$c $op v" "$table") | print_table
        fi
    else
        # String comparison (only == and != work for strings)
        if [[ "$op" == "==" ]]; then
            if [ "$DBMS_MODE" = "gui" ]; then
                local output=$((head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" 'NR > 1 {val_col = $c; gsub(/^ +| +$/, "", val_col); if (val_col == v) print $0}' "$table") | print_table)
                show_results "Query Results: $table_name" "$output" 800 500
            else
                echo -e "\n--- Query Results: $table_name ---"
                (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" 'NR > 1 {val_col = $c; gsub(/^ +| +$/, "", val_col); if (val_col == v) print $0}' "$table") | print_table
            fi
        elif [[ "$op" == "!=" ]]; then
            if [ "$DBMS_MODE" = "gui" ]; then
                local output=$((head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" 'NR > 1 {val_col = $c; gsub(/^ +| +$/, "", val_col); if (val_col != v) print $0}' "$table") | print_table)
                show_results "Query Results: $table_name" "$output" 800 500
            else
                echo -e "\n--- Query Results: $table_name ---"
                (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v v="$val" 'NR > 1 {val_col = $c; gsub(/^ +| +$/, "", val_col); if (val_col != v) print $0}' "$table") | print_table
            fi
        else
            if [ "$DBMS_MODE" = "gui" ]; then
                show_error_dialog "Operator $op not supported for string values. Use == or !="
            else
                echo "Error: Operator $op not supported for string values. Use == or != for strings."
            fi
            return 1
        fi
    fi
}

# Function to handle numerical conditions (kept for backward compatibility)
select_numerical_condition() {
    local table=$1
    local col=$2
    local op=$3
    local val=$4
    
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi

    # If parameters not provided, prompt for them
    if [[ -z "$col" ]] || [[ -z "$op" ]] || [[ -z "$val" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            col=$(show_entry_dialog "Numerical Condition" "Enter column name:" "")
            if [ $? -ne 0 ] || [ -z "$col" ]; then
                return
            fi
            
            local col_idx=$(get_col_index "$table" "$col")
            if [[ $col_idx -eq -1 ]]; then
                show_error_dialog "Column '$col' not found."
                return
            fi
            
            op=$(show_entry_dialog "Operator" "Enter operator (==, !=, >, <, >=, <=):" "==")
            if [ $? -ne 0 ] || [ -z "$op" ]; then
                return
            fi
            
            val=$(show_entry_dialog "Value" "Enter value:" "")
            if [ $? -ne 0 ] || [ -z "$val" ]; then
                return
            fi
        else
            read -p "Enter column name: " col
            local col_idx=$(get_col_index "$table" "$col")

            if [[ $col_idx -eq -1 ]]; then
                echo "Column '$col' not found."
                return
            fi

            read -p "Enter operator (==, !=, >, <, >=, <=): " op
            read -p "Enter value: " val
        fi
    fi

    # Use the new select_where function
    select_where "$table" "$col" "$op" "$val"
}

# Function to handle string conditions
select_string_condition() {
    local table=$1
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' not found."
        return
    fi

    if [ "$DBMS_MODE" = "gui" ]; then
        col=$(show_entry_dialog "String Condition" "Enter column name:" "")
        if [ $? -ne 0 ] || [ -z "$col" ]; then
            return
        fi
        
        local col_idx=$(get_col_index "$table" "$col")
        if [[ $col_idx -eq -1 ]]; then
            show_error_dialog "Column '$col' not found."
            return
        fi
        
        like_pattern=$(show_entry_dialog "LIKE Pattern" "Enter LIKE pattern (use % for wildcard):" "")
        if [ $? -ne 0 ] || [ -z "$like_pattern" ]; then
            return
        fi
    else
        read -p "Enter column name: " col
        local col_idx=$(get_col_index "$table" "$col")

        if [[ $col_idx -eq -1 ]]; then
            echo "Column '$col' not found."
            return
        fi

        read -p "Enter LIKE pattern: " like_pattern
    fi

    local regex_pattern="${like_pattern//%/.*}"
    regex_pattern="${regex_pattern//_/.}"
    regex_pattern="^$regex_pattern$"

    if [ "$DBMS_MODE" = "gui" ]; then
        local output=$((head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v p="$regex_pattern" 'NR > 1 {val = $c; gsub(/^ +| +$/, "", val); if (val ~ p) print $0}' "$table") | print_table)
        show_results "Query Results" "$output" 800 500
    else
        (head -n 1 "$table"; awk -F'|' -v c="$col_idx" -v p="$regex_pattern" 'NR > 1 {val = $c; gsub(/^ +| +$/, "", val); if (val ~ p) print $0}' "$table") | print_table
    fi
}

# Main Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tableName="$1"
    
    if [ "$DBMS_MODE" = "gui" ]; then
        # GUI Mode
        if [[ -z "$tableName" ]]; then
            # Get list of tables
            table_files=(*.meta)
            if [ ${#table_files[@]} -eq 0 ] || [ "${table_files[0]}" = "*.meta" ]; then
                show_error_dialog "No tables found in this database."
                exit 1
            fi
            
            table_options=()
            for meta_file in "${table_files[@]}"; do
                tbl_name="${meta_file%.meta}"
                if [[ -f "$tbl_name" ]]; then
                    table_options+=("FALSE" "$tbl_name")
                fi
            done
            
            result=$(yad --list --radiolist \
                --title="Select Table" \
                --text="Choose a table to query:" \
                --column="Select" --column="Table Name" \
                --width=400 --height=400 --center \
                --button="Cancel:1" --button="OK:0" \
                --print-column=2 \
                "${table_options[@]}")
            
            if [ $? -ne 0 ] || [ -z "$result" ]; then
                exit 0
            fi
            
            tableName=$(echo "$result" | tr -d '|' | xargs)
        fi
        
        # Validate table
        if [[ ! -f "$tableName" ]]; then
            show_error_dialog "Table $tableName does not exist."
            exit 1
        fi
        if [[ ! -f "$tableName.meta" ]]; then
            show_error_dialog "Metadata for $tableName does not exist."
            exit 1
        fi
        
        # Show select operations menu
        while true; do
            select_options=(
                "view-list" "Select All" "View all rows"
                "view-sort-ascending" "Select Specific Columns" "Choose columns to display"
                "edit-find" "Select by PK" "Find row by primary key"
                "preferences-system" "Numerical Condition" "Filter by number comparison"
                "edit-find-replace" "String Condition" "Filter by text pattern (LIKE)"
            )
            
            choice=$(show_options "Select from Table: $tableName" "Choose a query operation:" "${select_options[@]}")
            
            if [ $? -ne 0 ] || [ -z "$choice" ]; then
                break
            fi
            
            case "$choice" in
                "Select All")
                    select_all "$tableName"
                    ;;
                "Select Specific Columns")
                    header_line=$(head -n 1 "$tableName")
                    IFS='|' read -r -a headers <<< "$header_line"
                    
                    # Build checklist arguments for yad
                    col_args=()
                    for col in "${headers[@]}"; do
                        col_args+=("FALSE" "$col")
                    done
                    
                    # Show checklist dialog to select multiple columns
                    selected=$(yad --list --checklist \
                        --title="Select Columns" \
                        --text="Choose one or more columns to display:" \
                        --column="Select:CHK" --column="Column Name:TEXT" \
                        --width=500 --height=400 --center \
                        --button="Cancel:1" --button="OK:0" \
                        --print-column=2 \
                        --separator=" " \
                        "${col_args[@]}")
                    
                    if [ $? -eq 0 ] && [ -n "$selected" ]; then
                        # Trim and process the selected columns
                        columns=$(echo "$selected" | xargs)
                        if [ -n "$columns" ]; then
                            select_specific_columns "$tableName" "$columns"
                        else
                            show_error_dialog "No columns selected."
                        fi
                    fi
                    ;;
                "Select by PK")
                    select_by_pk "$tableName"
                    ;;
                "Numerical Condition")
                    select_numerical_condition "$tableName"
                    ;;
                "String Condition")
                    select_string_condition "$tableName"
                    ;;
            esac
        done
        
    else
        # CLI Mode
        while true; do
            if [[ -z "$tableName" ]]; then
                read -p "Enter table name: " tableName
            fi
            
            tableName="${tableName#"${tableName%%[![:space:]]*}"}"
            tableName="${tableName%"${tableName##*[![:space:]]}"}"

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
            "Select With Numerical Condition" \
            "Select With String Condition" \
            "Back"
        do
            case "$REPLY" in
                1) select_all "$tableName" ;;
                2) 
                    read -p "Enter column names (space-separated): " columns
                    select_specific_columns "$tableName" "$columns"
                    ;;
                3) select_by_pk "$tableName" ;;
                4) select_numerical_condition "$tableName" ;;
                5) select_string_condition "$tableName" ;;
                6) break ;;
                *) echo "Invalid choice" ;;
            esac
        done
    fi
fi
