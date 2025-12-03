#!/usr/bin/bash

# DEBUG
# echo "DEBUG: 1=$1 2=$2 3=$3"

# ==================== FUNCTION: Update rows by WHERE condition ====================
update_by_where() {
    local table="$1"
    shift
    
    # Parse SET assignments and WHERE condition
    # Expected format: SET col1=val1, col2=val2 WHERE column operator value
    
    local set_part=""
    local where_part=""
    local found_where=0
    local found_set=0
    
    # Collect arguments
    for arg in "$@"; do
        if [[ "${arg^^}" == "WHERE" ]]; then
            found_where=1
            continue
        fi
        
        if [[ "${arg^^}" == "SET" ]]; then
            found_set=1
            continue
        fi

        if [[ "$found_where" -eq 1 ]]; then
            where_part+="$arg "
        elif [[ "$found_set" -eq 1 ]]; then
            set_part+="$arg "
        fi
    done
    
    if [[ $found_where -eq 0 ]]; then
        echo "Error: WHERE clause required."
        return 1
    fi
    
    if [[ -z "$set_part" ]]; then
        echo "Error: SET clause required."
        return 1
    fi

    # Parse WHERE part
    # Expected: column operator value
    # But value might be quoted or contain spaces if we were smarter, but for now assume simple tokens
    # We need to be careful about how we split where_part
    
    # Use xargs to trim
    where_part=$(echo "$where_part" | xargs)
    
    # Split where_part into col, op, val
    # We assume the operator is one of the standard ones and is surrounded by spaces or we can find it
    
    local where_col=""
    local where_op=""
    local where_val=""
    
    # Simple splitting by space
    read -r where_col where_op where_val <<< "$where_part"
    
    if [[ -z "$where_col" || -z "$where_op" || -z "$where_val" ]]; then
        echo "Error: Invalid WHERE clause format. Expected: column operator value"
        return 1
    fi
    
    # Remove quotes from where value if present
    if [[ ${#where_val} -ge 2 && ${where_val:0:1} == "'" && ${where_val: -1} == "'" ]]; then
        where_val="${where_val:1:${#where_val}-2}"
    fi
    
    # Parse SET assignments
    # set_part can be "col1=val1, col2=val2" or "col1=val1,col2=val2"
    # We replace commas with spaces to make it easier to iterate, BUT values might contain spaces?
    # For this level of DBMS, we assume values don't contain commas if they are not quoted.
    # Let's try to respect commas.
    
    declare -A updates
    
    # Split by comma
    IFS=',' read -ra assign_parts <<< "$set_part"
    
    for assign in "${assign_parts[@]}"; do
        # Trim spaces
        assign=$(echo "$assign" | xargs)
        
        if [[ -z "$assign" ]]; then continue; fi
        
        # Split by first =
        local col="${assign%%=*}"
        local val="${assign#*=}"
        
        # Trim spaces
        col=$(echo "$col" | xargs)
        val=$(echo "$val" | xargs)
        
        # Remove quotes from value
        if [[ ${#val} -ge 2 && ${val:0:1} == "'" && ${val: -1} == "'" ]]; then
            val="${val:1:${#val}-2}"
        fi
        
        updates["$col"]="$val"
    done

    # Get header and column indices
    header_line=$(head -n 1 "$table")
    IFS='|' read -r -a headers <<< "$header_line"
    
    # Get WHERE column index
    where_col_idx=-1
    for i in "${!headers[@]}"; do
        if [[ "${headers[$i]}" == "$where_col" ]]; then
            where_col_idx=$((i + 1))
            break
        fi
    done

    if [[ $where_col_idx -eq -1 ]]; then
        echo "WHERE column '$where_col' not found in table '$table'."
        return 1
    fi

    # Get update column indices
    declare -A col_indices
    for col in "${!updates[@]}"; do
        found=0
        for i in "${!headers[@]}"; do
            if [[ "${headers[$i]}" == "$col" ]]; then
                col_indices["$col"]=$((i + 1))
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            echo "Column '$col' not found in table '$table'."
            return 1
        fi
    done

    # Build awk condition for WHERE clause
    case "$where_op" in
        "=="|"=")
            awk_cond="\$wc == wv"
            ;;
        "!=")
            awk_cond="\$wc != wv"
            ;;
        ">")
            awk_cond="\$wc > wv"
            ;;
        "<")
            awk_cond="\$wc < wv"
            ;;
        ">=")
            awk_cond="\$wc >= wv"
            ;;
        "<=")
            awk_cond="\$wc <= wv"
            ;;
        "LIKE"|"like")
            regex_pattern="${where_val//%/.*}"
            regex_pattern="${regex_pattern//_/.}"
            regex_pattern="^$regex_pattern$"
            awk_cond="\$wc ~ wv"
            where_val="$regex_pattern"
            ;;
        *)
            echo "Unknown operator: $where_op"
            echo "Supported: =, !=, >, <, >=, <=, LIKE"
            return 1
            ;;
    esac

    # Count matching rows
    # We use a temporary awk script to check matches
    match_count=$(awk -F'|' -v wc="$where_col_idx" -v wv="$where_val" "NR > 1 && $awk_cond {count++} END{print count+0}" "$table")

    if [[ "$match_count" -eq 0 ]]; then
        echo "No rows match the WHERE condition."
        return 0
    fi

    # Perform Update directly without confirmation for SQL mode (as per requirement "No interactive prompts")
    # But wait, the user requirement said "No interactive prompts. The update must run directly based on the SQL typed."
    # So we should skip the confirmation if we are in SQL mode.
    # The function is called from both interactive and SQL mode.
    # We can check if we are in interactive mode or not, or just assume if arguments are passed we skip confirmation?
    # The prompt says "No interactive prompts. The update must run directly based on the SQL typed."
    # I will remove the confirmation prompt for this function.
    
    # Build awk script to update matching rows
    awk_script="BEGIN { FS=OFS=\"|\" } "
    awk_script+="NR == 1 { print; next } "
    awk_script+="{ if ($awk_cond) { "
    
    for col in "${!col_indices[@]}"; do
        idx="${col_indices[$col]}"
        val="${updates[$col]}"
        awk_script+="\$$idx=\"$val\"; "
    done
    
    awk_script+="} print }"

    awk -v wc="$where_col_idx" -v wv="$where_val" "$awk_script" "$table" > "$table.tmp" && mv "$table.tmp" "$table"
    
    echo "Updated $match_count row(s) in '$table'."
    return 0
}

# ==================== FUNCTION: Update by primary key ====================
update_by_pk() {
    local table="$1"
    local pk_col_index="$2"
    local pk_col_name="$3"
    
    echo "Primary key column is: $pk_col_name"

    local pk_val
    local target_line
    
    while true
    do
        read -p "Enter primary key value of the row to update: " pk_val

        # Trim spaces
        pk_val="${pk_val#"${pk_val%%[![:space:]]*}"}"
        pk_val="${pk_val%"${pk_val##*[![:space:]]}"}"

        if [[ -z "$pk_val" ]]; then
            echo "Primary key value cannot be empty."
            continue
        fi

        pk_idx0=$((pk_col_index - 1))

        # Find line number of the row with this PK
        line_no=0
        target_line=0

        while IFS='|' read -r -a fields; do
            line_no=$((line_no + 1))

            # Skip header (line 1)
            if [[ $line_no -eq 1 ]]; then
                continue
            fi

            # Skip empty lines
            [[ ${#fields[@]} -eq 0 ]] && continue

            # Compare PK column with requested value
            if [[ "${fields[$pk_idx0]}" == "$pk_val" ]]; then
                target_line=$line_no
                break
            fi
        done < "$table"

        if [[ $target_line -eq 0 ]]; then
            echo "No row with primary key '$pk_val' found in table '$table'."
            continue
        fi

        echo "Row found at line $target_line."
        break
    done

    # Read header from data file
    header_line=$(head -n 1 "$table")
    IFS='|' read -r -a header_cols <<< "$header_line"

    # Ask which column to update
    echo "Columns in '$table':"
    for ((i=0; i<${#header_cols[@]}; i++)); do
        num=$((i+1))
        printf "  %d) %s\n" "$num" "${header_cols[$i]}"
    done

    local col_name
    local col_index
    local attempt=0
    
    while true; do
        read -p "Enter column name to update: " col_name

        # Trim spaces
        col_name="${col_name#"${col_name%%[![:space:]]*}"}"
        col_name="${col_name%"${col_name##*[![:space:]]}"}"

        if [[ -z "$col_name" ]]; then
            echo "Column name cannot be empty."
            ((attempt++))
            if [[ $attempt -ge 3 ]]; then
                echo "Invalid input entered 3 times. Exiting."
                return 1
            fi
            continue
        fi

        # Find column index from column name
        col_index=-1
        for ((i=0; i<${#header_cols[@]}; i++)); do
            if [[ "${header_cols[$i]}" == "$col_name" ]]; then
                col_index=$((i+1))
                break
            fi
        done

        if [[ $col_index -eq -1 ]]; then
            echo "Column '$col_name' not found in table '$table'."
            ((attempt++))
            if [[ $attempt -ge 3 ]]; then
                echo "Invalid column name entered 3 times. Exiting."
                return 1
            fi
            continue
        fi
        
        break
    done

    col_idx0=$((col_index - 1))

    # Ask for new value
    read -p "Enter new value for column '$col_name': " new_val

    # Trim spaces
    new_val="${new_val#"${new_val%%[![:space:]]*}"}"
    new_val="${new_val%"${new_val##*[![:space:]]}"}"

    # If this column is PK, enforce NOT NULL and UNIQUE
    if [[ $pk_col_index -ne -1 && $col_index -eq $pk_col_index ]]; then
        # Not null check
        if [[ -z "$new_val" ]]; then
            echo "Primary key value cannot be NULL or empty."
            return 1
        fi

        # Uniqueness check (no other row can have this PK)
        pk_idx0=$((pk_col_index - 1))
        line_no=0
        duplicate_found=0

        while IFS='|' read -r -a fields; do
            line_no=$((line_no + 1))

            # Skip header
            if [[ $line_no -eq 1 ]]; then
                continue
            fi

            # Skip the row we are updating
            if [[ $line_no -eq $target_line ]]; then
                continue
            fi

            if [[ "${fields[$pk_idx0]}" == "$new_val" ]]; then
                duplicate_found=1
                break
            fi
        done < "$table"

        if [[ $duplicate_found -eq 1 ]]; then
            echo "Another row already has primary key value '$new_val'. Update cancelled."
            return 1
        fi
    fi

    # Confirm and apply the update
    echo -e "\nYou are about to update:"
    echo "  Table : $table"
    echo "  Column: $col_name"
    echo "  New value: $new_val"

    read -p "Are you sure you want to apply this change? [y/n]: " confirm
    confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')

    if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
        echo "Update cancelled."
        return 0
    fi

    # Create tmp file and rebuild table with updated value
    line_no=0

    {
        # Read the header line first and print as is
        IFS= read -r line
        echo "$line"

        # Now process the rest of the lines (data rows)
        while IFS='|' read -r -a fields; do
            line_no=$((line_no + 1))
            file_line=$((line_no + 1))

            # If line is empty, just print empty line
            if [[ ${#fields[@]} -eq 0 ]]; then
                echo ""
                continue
            fi

            if [[ $file_line -eq $target_line ]]; then
                # This is the row we want to update
                fields[$col_idx0]="$new_val"
            fi

            # Rebuild line from fields array
            out="${fields[0]}"
            for ((i=1; i<${#fields[@]}; i++)); do
                out+="|${fields[$i]}"
            done
            echo "$out"
        done
    } < "$table" > "$table.tmp"

    # Replace original table with updated version
    mv "$table.tmp" "$table"
    echo "Value updated successfully in table '$table'."
    return 0
}

# ==================== MAIN SCRIPT ====================

# Check if SQL-like syntax is being used (SET keyword)
if [[ "${2,,}" == "set" ]]; then
    # ============ SQL-LIKE MODE ============
    table="$1"
    
    # Check if table exists
    if [[ ! -f "$table" ]]; then
        echo "Table '$table' does not exist."
        exit 1
    fi

    if [[ ! -f "$table.meta" ]]; then
        echo "Metadata file '$table.meta' not found for table '$table'."
        exit 1
    fi

    # Call update_by_where with all arguments
    update_by_where "$@"
    exit $?
fi

# ============ INTERACTIVE MODE ============

# Ask for table name
table="$1"

while true
do
    # Ask user for table name if not provided
    if [[ -z "$table" ]]; then
        read -p "Enter table name: " table
    fi

    # Trim leading spaces
    table="${table#"${table%%[![:space:]]*}"}"
    # Trim trailing spaces
    table="${table%"${table##*[![:space:]]}"}"

    # Check empty
    if [[ -z "$table" ]]; then
        echo "Table name cannot be empty."
        table=""
        continue
    fi

    # Data file = table, Meta file = table.meta
    data_file="$table"
    meta_file="$table.meta"

    # Check data file exists
    if [[ ! -f "$data_file" ]]; then
        echo "Table '$table' does not exist in this database."
        table=""
        continue
    fi

    # Check metadata file exists
    if [[ ! -f "$meta_file" ]]; then
        echo "Metadata file '$meta_file' not found for table '$table'."
        table=""
        continue
    fi

    break
done

# Find primary key column
meta_line=$(head -n 1 "$meta_file")
IFS='|' read -r -a meta_cols <<< "$meta_line"

pk_col_index=-1
pk_col_name=""

# Loop over each metadata column entry
for ((i=0; i<${#meta_cols[@]}; i++)); do
    col_meta="${meta_cols[$i]}"
    IFS=':' read -r -a parts <<< "$col_meta"

    col_name="${parts[0]}"
    last_part="${parts[${#parts[@]}-1]}"

    if [[ "$last_part" == "PK" ]]; then
        pk_col_index=$((i+1))
        pk_col_name="$col_name"
        break
    fi
done

# Update menu
echo -e "\n-----------------------------"
echo "     Update Operations      "
echo -e "-----------------------------\n"

PS3="Choose update operation: "

select choice in "Update Row (by PK)" "Update Rows (by WHERE)" "Cancel"
do
    case "$REPLY" in
        # UPDATE BY PRIMARY KEY
        1)
            update_by_pk "$data_file" "$pk_col_index" "$pk_col_name"
            break
            ;;

        # UPDATE BY WHERE CONDITION
        2)
            # Get header
            header_line=$(head -n 1 "$data_file")
            IFS='|' read -r -a headers <<< "$header_line"
            
            echo "Available columns:"
            for ((i=0; i<${#headers[@]}; i++)); do
                echo "  - ${headers[$i]}"
            done
            
            # Get columns to update
            read -p "Enter column(s) to update (comma-separated, e.g., name,age): " cols_input
            read -p "Enter new value(s) (comma-separated, e.g., John,30): " vals_input
            
            # Build SET clause
            IFS=',' read -ra col_arr <<< "$cols_input"
            IFS=',' read -ra val_arr <<< "$vals_input"
            
            set_clause=""
            for ((i=0; i<${#col_arr[@]}; i++)); do
                c="${col_arr[$i]}"
                v="${val_arr[$i]}"
                # Trim
                c="${c#"${c%%[![:space:]]*}"}"
                c="${c%"${c##*[![:space:]]}"}"
                v="${v#"${v%%[![:space:]]*}"}"
                v="${v%"${v##*[![:space:]]}"}"
                
                if [[ $i -eq 0 ]]; then
                    set_clause="$c=$v"
                else
                    set_clause="$set_clause,$c=$v"
                fi
            done
            
            # Get WHERE clause
            read -p "Enter WHERE column name: " where_col
            read -p "Enter operator (==, !=, >, <, >=, <=, LIKE): " where_op
            read -p "Enter value: " where_val
            
            # Trim
            where_col="${where_col#"${where_col%%[![:space:]]*}"}"
            where_col="${where_col%"${where_col##*[![:space:]]}"}"
            where_val="${where_val#"${where_val%%[![:space:]]*}"}"
            where_val="${where_val%"${where_val##*[![:space:]]}"}"
            
            # Call update_by_where
            update_by_where "$data_file" "SET" "$set_clause" "WHERE" "$where_col" "$where_op" "$where_val"
            break
            ;;

        # CANCEL
        3)
            echo -e "\nUpdate operation cancelled."
            break
            ;;

        *)
            echo -e "\nInvalid choice, try again.\n"
            ;;
    esac
done
