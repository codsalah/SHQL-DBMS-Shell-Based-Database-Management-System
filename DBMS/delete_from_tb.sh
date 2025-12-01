#!/usr/bin/bash

# Validate and ask for table name

while true
do
    
    read -p "Enter table name: " table

    # Trim leading spaces
    table="${table#"${table%%[![:space:]]*}"}"
    # Trim trailing spaces
    table="${table%"${table##*[![:space:]]}"}"

    # Check empty
    if [[ -z "$table" ]]; then
        echo "Table name cannot be empty."
        continue
    fi

    data_file="$table"
    meta_file="$table.meta"

    # Check both data and meta files exist
    if [[ ! -f "$data_file" ]]; then
        echo "Table '$table' does not exist."
        continue
    fi

    if [[ ! -f "$meta_file" ]]; then
        echo "Metadata file '$meta_file' not found for table '$table'."
        continue
    fi

    break
done

# Get primary key column index

# Read metadata line (single line)
meta_line=$(head -n 1 "$meta_file")

# Split metadata by | into array
IFS='|' read -r -a meta_cols <<< "$meta_line"

pk_col_index=-1
pk_col_name=""

# Loop over each column meta entry to find the one with PK
for ((i=0; i<${#meta_cols[@]}; i++)); do
    col_meta="${meta_cols[$i]}"
    IFS=':' read -r -a parts <<< "$col_meta"   # split meta of each column

    col_name="${parts[0]}"
    last_part="${parts[${#parts[@]}-1]}"

    if [[ "$last_part" == "PK" ]]; then
        pk_col_index=$((i+1))        # store as 1-based index
        pk_col_name="$col_name"
        break
    fi
done

# Delete menu: row or column
echo -e "\n-----------------------------"
echo "     Delete Operations      "
echo -e "-----------------------------\n"

PS3="Choose delete operation: "

select choice in "Delete Row" "Delete Column" "Cancel"
do
    case "$REPLY" in

        # DELETE ROW BY PRIMARY KEY
        1)
            
            echo "Primary key column is: $pk_col_name"

            # Ask for primary key value
            read -p "Enter primary key value of the row to delete: " pk_val

            # Trim spaces
            pk_val="${pk_val#"${pk_val%%[![:space:]]*}"}"
            pk_val="${pk_val%"${pk_val##*[![:space:]]}"}"

            if [[ -z "$pk_val" ]]; then
                echo -e "\nPrimary key value cannot be empty."
                break
            fi

            # Check if any row has this PK value
            match_count=$(awk -F'|' -v c="$pk_col_index" -v v="$pk_val" 'NR>1 && $c==v {count++} END{print count}' "$data_file")

            if [[ "$match_count" -eq 0 ]]; then
                echo -e "\nNo row with PK '$pk_val' found in table '$table'."
                break
            fi

            # Confirm deletion
            read -p "Are you sure you want to delete row with PK '$pk_val' from '$table'? [y/n]: " confirm
            confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')

            if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
                # Keep header (NR==1) and all rows where PK column != value
                awk -F'|' -v c="$pk_col_index" -v v="$pk_val" 'NR==1 || $c!=v' "$data_file" > "$data_file.tmp"
                mv "$data_file.tmp" "$data_file"

                echo -e "\nRow with PK '$pk_val' deleted from '$table'."
            else
                echo -e "\nRow deletion cancelled."
            fi
            break
            ;;

        # DELETE COLUMN BY NAME
        2)
            # Show current columns from header
            header_line=$(head -n 1 "$data_file")
            IFS='|' read -r -a header_cols <<< "$header_line"

            echo "Columns in '$table':"
            for ((i=0; i<${#header_cols[@]}; i++)); do
                echo "$((i+1))) ${header_cols[$i]}"
            done

            read -p "Enter column name to delete: " col_name

            # Trim spaces
            col_name="${col_name#"${col_name%%[![:space:]]*}"}"
            col_name="${col_name%"${col_name##*[![:space:]]}"}"

            if [[ -z "$col_name" ]]; then
                echo -e "\nColumn name cannot be empty."
                break
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
                echo "Column '$col_name' not found in table '$table'."
                break
            fi

            # Prevent deleting PK column
            if [[ $col_index -eq $pk_col_index ]]; then
                echo -e "\nCannot delete primary key column '$col_name'."
                break
            fi

            # Confirm deletion
            read -p "Are you sure you want to delete column '$col_name' from '$table'? [y/n]: " confirm
            confirm=$(echo "$confirm" | tr 'A-Z' 'a-z')

            if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
                # Remove the selected column from the data file
		cut -d '|' --complement -f "$col_index" "$data_file" > "$data_file.tmp"
		mv "$data_file.tmp" "$data_file"

                # Remove this column from metadata file
                cut -d '|' --complement -f "$col_index" "$meta_file" > "$meta_file.tmp"
		mv "$meta_file.tmp" "$meta_file"

                echo "Column '$col_name' deleted from table '$table' and metadata."
            else
                echo -e "\nColumn deletion cancelled."
            fi
            break
            ;;

        # CANCEL
        3)
            echo -e "\nDelete operation cancelled."
            break
            ;;

        *)
            echo -e "\nInvalid choice, try again.\n"
            ;;
    esac
done

