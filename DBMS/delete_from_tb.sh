#!/usr/bin/bash

# Source YAD utility functions
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/yad_utilities.sh"

# ==================== FUNCTION: Delete rows by WHERE condition ====================
delete_by_where() {
    local table="$1"
    local where_col="$2"
    local operator="$3"
    local value="$4"

    # Get column index
    header_line=$(head -n 1 "$table")
    IFS='|' read -r -a headers <<< "$header_line"
    
    col_idx=-1
    for i in "${!headers[@]}"; do
        if [[ "${headers[$i]}" == "$where_col" ]]; then
            col_idx=$((i + 1))
            break
        fi
    done

    if [[ $col_idx -eq -1 ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Column '$where_col' not found in table '$table'."
        else
            echo "Column '$where_col' not found in table '$table'."
        fi
        return 1
    fi

    # Build awk condition based on operator
    case "$operator" in
        "=="|"=")
            awk_cond="\$c == v"
            ;;
        "!=")
            awk_cond="\$c != v"
            ;;
        ">")
            awk_cond="\$c > v"
            ;;
        "<")
            awk_cond="\$c < v"
            ;;
        ">=")
            awk_cond="\$c >= v"
            ;;
        "<=")
            awk_cond="\$c <= v"
            ;;
        "LIKE"|"like")
            # Convert SQL LIKE to regex
            regex_pattern="${value//%/.*}"
            regex_pattern="${regex_pattern//_/.}"
            regex_pattern="^$regex_pattern$"
            awk_cond="\$c ~ v"
            value="$regex_pattern"
            ;;
        *)
            if [ "$DBMS_MODE" = "gui" ]; then
                show_error_dialog "Unknown operator: $operator\nSupported: ==, !=, >, <, >=, <=, LIKE"
            else
                echo "Unknown operator: $operator"
                echo "Supported: ==, !=, >, <, >=, <=, LIKE"
            fi
            return 1
            ;;
    esac

    # Count rows that will be deleted
    match_count=$(awk -F'|' -v c="$col_idx" -v v="$value" "NR > 1 && $awk_cond {count++} END{print count+0}" "$table")

    if [[ "$match_count" -eq 0 ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "No Match" "No rows match the condition."
        else
            echo "No rows match the condition."
        fi
        return 0
    fi

    # Confirm deletion
    if [ "$DBMS_MODE" = "gui" ]; then
        show_question_dialog "$match_count row(s) will be deleted. Confirm deletion?"
        if [ $? -ne 0 ]; then
            show_info_dialog "Cancelled" "Deletion cancelled."
            return 0
        fi
        confirm="y"
    else
        echo "$match_count row(s) will be deleted."
        read -p "Confirm deletion? [y/n]: " confirm
        confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')
    fi

    if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
        # Keep header and rows that DON'T match condition
        awk -F'|' -v c="$col_idx" -v v="$value" "NR == 1 || !($awk_cond)" "$table" > "$table.tmp"
        mv "$table.tmp" "$table"
        
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Success" "Deleted $match_count row(s) from '$table'."
        else
            echo "Deleted $match_count row(s) from '$table'."
        fi
        return 0
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Cancelled" "Deletion cancelled."
        else
            echo "Deletion cancelled."
        fi
        return 0
    fi
}

# ==================== FUNCTION: Delete row by primary key ====================
delete_by_pk() {
    local table="$1"
    local pk_col_index="$2"
    local pk_col_name="$3"
    
    if [ "$DBMS_MODE" != "gui" ]; then
        echo "Primary key column is: $pk_col_name"
    fi

    # Ask for primary key value
    if [ "$DBMS_MODE" = "gui" ]; then
        pk_val=$(show_entry_dialog "Delete Row by PK" "Primary key column: $pk_col_name\n\nEnter primary key value of the row to delete:" "")
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        read -p "Enter primary key value of the row to delete: " pk_val
    fi

    # Trim spaces
    pk_val="${pk_val#"${pk_val%%[![:space:]]*}"}"
    pk_val="${pk_val%"${pk_val##*[![:space:]]}"}"

    if [[ -z "$pk_val" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Primary key value cannot be empty."
        else
            echo -e "\nPrimary key value cannot be empty."
        fi
        return 1
    fi

    # Check if any row has this PK value
    match_count=$(awk -F'|' -v c="$pk_col_index" -v v="$pk_val" 'NR>1 && $c==v {count++} END{print count+0}' "$table")

    if [[ "$match_count" -eq 0 ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "No row with PK '$pk_val' found in table '$table'."
        else
            echo -e "\nNo row with PK '$pk_val' found in table '$table'."
        fi
        return 1
    fi

    # Confirm deletion
    if [ "$DBMS_MODE" = "gui" ]; then
        show_question_dialog "Are you sure you want to delete row with PK '$pk_val' from '$table'?"
        if [ $? -ne 0 ]; then
            show_info_dialog "Cancelled" "Row deletion cancelled."
            return 0
        fi
        confirm="y"
    else
        read -p "Are you sure you want to delete row with PK '$pk_val' from '$table'? [y/n]: " confirm
        confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')
    fi

    if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
        # Keep header (NR==1) and all rows where PK column != value
        awk -F'|' -v c="$pk_col_index" -v v="$pk_val" 'NR==1 || $c!=v' "$table" > "$table.tmp"
        mv "$table.tmp" "$table"

        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Success" "Row with PK '$pk_val' deleted from '$table'."
        else
            echo -e "\nRow with PK '$pk_val' deleted from '$table'."
        fi
        return 0
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Cancelled" "Row deletion cancelled."
        else
            echo -e "\nRow deletion cancelled."
        fi
        return 0
    fi
}

# ==================== FUNCTION: Delete column ====================
delete_column() {
    local table="$1"
    local pk_col_index="$2"
    
    # Show current columns from header
    header_line=$(head -n 1 "$table")
    IFS='|' read -r -a header_cols <<< "$header_line"

    if [ "$DBMS_MODE" = "gui" ]; then
        # Build options for GUI
        col_options=()
        for ((i=0; i<${#header_cols[@]}; i++)); do
            col_options+=("text-x-generic" "${header_cols[$i]}" "Column")
        done
        
        col_name=$(show_options "Delete Column" "Select column to delete from '$table':" "${col_options[@]}")
        if [ $? -ne 0 ] || [ -z "$col_name" ]; then
            return 1
        fi
    else
        echo "Columns in '$table':"
        for ((i=0; i<${#header_cols[@]}; i++)); do
            num=$((i+1))
            printf "%d) %s\n" "$num" "${header_cols[$i]}"
        done
        
        read -p "Enter column name to delete: " col_name
    fi

    # Trim spaces
    col_name="${col_name#"${col_name%%[![:space:]]*}"}"
    col_name="${col_name%"${col_name##*[![:space:]]}"}"

    if [[ -z "$col_name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Column name cannot be empty."
        else
            echo -e "\nColumn name cannot be empty."
        fi
        return 1
    fi

    # Find index of this column in header
    col_index=-1
    for ((i=0; i<${#header_cols[@]}; i++)); do
        if [[ "${header_cols[$i]}" == "$col_name" ]]; then
            col_index=$((i+1))   # 1-based
            break
        fi
    done

    if [[ $col_index -eq -1 ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Column '$col_name' not found in table '$table'."
        else
            echo "Column '$col_name' not found in table '$table'."
        fi
        return 1
    fi

    # Prevent deleting PK column
    if [[ $col_index -eq $pk_col_index ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Cannot delete primary key column '$col_name'."
        else
            echo -e "\nCannot delete primary key column '$col_name'."
        fi
        return 1
    fi

    # Confirm deletion
    if [ "$DBMS_MODE" = "gui" ]; then
        show_question_dialog "Are you sure you want to delete column '$col_name' from '$table'?"
        if [ $? -ne 0 ]; then
            show_info_dialog "Cancelled" "Column deletion cancelled."
            return 0
        fi
        confirm="y"
    else
        read -p "Are you sure you want to delete column '$col_name' from '$table'? [y/n]: " confirm
        confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')
    fi

    if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
        # Remove the selected column from the data file
        cut -d '|' --complement -f "$col_index" "$table" > "$table.tmp"
        mv "$table.tmp" "$table"

        # Remove this column from metadata file
        cut -d '|' --complement -f "$col_index" "$table.meta" > "$table.meta.tmp"
        mv "$table.meta.tmp" "$table.meta"

        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Success" "Column '$col_name' deleted from table '$table' and metadata."
        else
            echo "Column '$col_name' deleted from table '$table' and metadata."
        fi
        return 0
    else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Cancelled" "Column deletion cancelled."
        else
            echo -e "\nColumn deletion cancelled."
        fi
        return 0
    fi
}

# ==================== MAIN SCRIPT ====================

# Check if SQL-like syntax is being used (WHERE keyword)
if [[ "$2" == "WHERE" || "$2" == "where" ]]; then
    # ============ SQL-LIKE MODE ============
    table="$1"
    where_col="$3"
    operator="$4"
    value="$5"

    # Check if table exists
    if [[ ! -f "$table" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Table '$table' does not exist."
        else
            echo "Table '$table' does not exist."
        fi
        exit 1
    fi

    if [[ ! -f "$table.meta" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Metadata file '$table.meta' not found for table '$table'."
        else
            echo "Metadata file '$table.meta' not found for table '$table'."
        fi
        exit 1
    fi

    # Remove quotes from value if present
    if [[ ${#value} -ge 2 && ${value:0:1} == "'" && ${value: -1} == "'" ]]; then
        value="${value:1:${#value}-2}"
    fi

    # Call the delete_by_where function
    delete_by_where "$table" "$where_col" "$operator" "$value"
    exit $?
fi

# ============ INTERACTIVE MODE ============

# Validate and ask for table name
table="$1"

while true
do
    if [[ -z "$table" ]]; then
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
                show_info_dialog "Delete from Table" "No tables available."
                exit 0
            fi
            
            table=$(show_options "Delete from Table" "Select a table:" "${tb_options[@]}")
            if [ $? -ne 0 ] || [ -z "$table" ]; then
                exit 0
            fi
        else
            read -p "Enter table name: " table
        fi
    fi

    # Trim leading spaces
    table="${table#"${table%%[![:space:]]*}"}"
    # Trim trailing spaces
    table="${table%"${table##*[![:space:]]}"}"

    # Check empty
    if [[ -z "$table" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Table name cannot be empty."
        else
            echo "Table name cannot be empty."
        fi
        table=""
        continue
    fi

    data_file="$table"
    meta_file="$table.meta"

    # Check both data and meta files exist
    if [[ ! -f "$data_file" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Table '$table' does not exist."
        else
            echo "Table '$table' does not exist."
        fi
        table=""
        continue
    fi

    if [[ ! -f "$meta_file" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Metadata file '$meta_file' not found for table '$table'."
        else
            echo "Metadata file '$meta_file' not found for table '$table'."
        fi
        table=""
        continue
    fi

    break
done

# Get primary key column index
meta_line=$(head -n 1 "$meta_file")
IFS='|' read -r -a meta_cols <<< "$meta_line"

pk_col_index=-1
pk_col_name=""

# Loop over each column meta entry to find the one with PK
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

# Delete menu: row or column
if [ "$DBMS_MODE" = "gui" ]; then
    # GUI mode - use show_options
    delete_options=(
        "edit-delete" "Delete Row (by PK)" "Delete a row using primary key"
        "edit-delete" "Delete Row (by WHERE)" "Delete rows matching condition"
        "edit-delete" "Delete Column" "Delete entire column"
    )
    
    choice=$(show_options "Delete Operations" "Choose delete operation for table '$table':" "${delete_options[@]}")
    ret=$?
    
    if [ $ret -ne 0 ] || [ -z "$choice" ]; then
        exit 0
    fi
    
    case "$choice" in
        "Delete Row (by PK)")
            delete_by_pk "$data_file" "$pk_col_index" "$pk_col_name"
            ;;
        "Delete Row (by WHERE)")
            # Get column name
            header_line=$(head -n 1 "$data_file")
            IFS='|' read -r -a headers <<< "$header_line"
            
            # Build column options
            col_opts=()
            for ((i=0; i<${#headers[@]}; i++)); do
                col_opts+=("text-x-generic" "${headers[$i]}" "Column")
            done
            
            col_name=$(show_options "Select Column" "Choose column for WHERE condition:" "${col_opts[@]}")
            if [ $? -ne 0 ] || [ -z "$col_name" ]; then
                exit 0
            fi
            
            # Get operator
            op_opts=(
                "dialog-information" "==" "Equal to"
                "dialog-information" "!=" "Not equal to"
                "dialog-information" ">" "Greater than"
                "dialog-information" "<" "Less than"
                "dialog-information" ">=" "Greater or equal"
                "dialog-information" "<=" "Less or equal"
                "dialog-information" "LIKE" "Pattern matching"
            )
            
            op=$(show_options "Select Operator" "Choose comparison operator:" "${op_opts[@]}")
            if [ $? -ne 0 ] || [ -z "$op" ]; then
                exit 0
            fi
            
            # Get value
            val=$(show_entry_dialog "Enter Value" "Enter value to compare with:" "")
            if [ $? -ne 0 ]; then
                exit 0
            fi
            
            # Trim value
            val="${val#"${val%%[![:space:]]*}"}"
            val="${val%"${val##*[![:space:]]}"}"
            
            delete_by_where "$data_file" "$col_name" "$op" "$val"
            ;;
        "Delete Column")
            delete_column "$data_file" "$pk_col_index"
            ;;
    esac
else
    # CLI mode - use select menu
    echo -e "\n-----------------------------"
    echo "     Delete Operations      "
    echo -e "-----------------------------\n"

    PS3="Choose delete operation: "

    select choice in "Delete Row (by PK)" "Delete Row (by WHERE)" "Delete Column" "Cancel"
    do
        case "$REPLY" in
            # DELETE ROW BY PRIMARY KEY
            1)
                delete_by_pk "$data_file" "$pk_col_index" "$pk_col_name"
                break
                ;;

            # DELETE ROW BY WHERE CONDITION
            2)
                # Get column name
                header_line=$(head -n 1 "$data_file")
                IFS='|' read -r -a headers <<< "$header_line"
                
                echo "Available columns:"
                for ((i=0; i<${#headers[@]}; i++)); do
                    echo "  - ${headers[$i]}"
                done
                
                read -p "Enter column name: " col_name
                col_name="${col_name#"${col_name%%[![:space:]]*}"}"
                col_name="${col_name%"${col_name##*[![:space:]]}"}"
                
                read -p "Enter operator (==, !=, >, <, >=, <=, LIKE): " op
                read -p "Enter value: " val
                
                # Trim value
                val="${val#"${val%%[![:space:]]*}"}"
                val="${val%"${val##*[![:space:]]}"}"
                
                delete_by_where "$data_file" "$col_name" "$op" "$val"
                break
                ;;

            # DELETE COLUMN BY NAME
            3)
                delete_column "$data_file" "$pk_col_index"
                break
                ;;

            # CANCEL
            4)
                echo -e "\nDelete operation cancelled."
                break
                ;;

            *)
                echo -e "\nInvalid choice, try again.\n"
                ;;
        esac
    done
fi
