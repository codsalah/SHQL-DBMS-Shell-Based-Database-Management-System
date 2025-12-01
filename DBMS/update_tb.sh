#!/usr/bin/bash

# Ask for table name

while true
do
    # Ask user for table name
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

    # Data file = table, Meta file = table.meta
    data_file="$table"
    meta_file="$table.meta"

    # Check data file exists
    if [[ ! -f "$data_file" ]]; then
        echo "Table '$table' does not exist in this database."
        continue
    fi

    # Check metadata file exists
    if [[ ! -f "$meta_file" ]]; then
        echo "Metadata file '$meta_file' not found for table '$table'."
        continue
    fi

    break
done

# Find primary key column

# Read the single metadata line
meta_line=$(head -n 1 "$meta_file")

# Split metadata into columns by |
IFS='|' read -r -a meta_cols <<< "$meta_line"

pk_col_index=-1
pk_col_name=""

# Loop over each metadata column entry
for ((i=0; i<${#meta_cols[@]}; i++)); do
    col_meta="${meta_cols[$i]}"

    # Split this meta by :
    IFS=':' read -r -a parts <<< "$col_meta"

    col_name="${parts[0]}"
    last_part="${parts[${#parts[@]}-1]}"

    if [[ "$last_part" == "PK" ]]; then
        pk_col_index=$((i+1))
        pk_col_name="$col_name"
        break
    fi
done

# Read header from data file (first line with column names)
header_line=$(head -n 1 "$data_file")
IFS='|' read -r -a header_cols <<< "$header_line"

# Ask for row (by PK value)

# Use PK to select the row
if [[ $pk_col_index -ne -1 ]]; then
    echo "Primary key column is: $pk_col_name"

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

        pk_idx0=$((pk_col_index - 1))  # convert PK index to 0-based for array access

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
        done < "$data_file"

        if [[ $target_line -eq 0 ]]; then
            echo "No row with primary key '$pk_val' found in table '$table'."
            continue
        fi

        echo "Row found at line $target_line."
        break
    done
else
    # No PK defined: we cannot select by PK, so ask for line number directly
    echo "No primary key found."
fi

# Ask which column to update

echo "Columns in '$table':"
for ((i=0; i<${#header_cols[@]}; i++)); do
    echo "  $((i+1))) ${header_cols[$i]}"
done

read -p "Enter column name to update: " col_name

# Trim spaces
col_name="${col_name#"${col_name%%[![:space:]]*}"}"
col_name="${col_name%"${col_name##*[![:space:]]}"}"

if [[ -z "$col_name" ]]; then
    echo "Column name cannot be empty."
    exit 0
fi

# Find column index from column name
col_index=-1
for ((i=0; i<${#header_cols[@]}; i++)); do
    if [[ "${header_cols[$i]}" == "$col_name" ]]; then
        col_index=$((i+1))    # 1-based
        break
    fi
done

if [[ $col_index -eq -1 ]]; then
    echo "Column '$col_name' not found in table '$table'."
    exit 0
fi

col_idx0=$((col_index - 1))

# Ask for new value, with PK rules if needed

read -p "Enter new value for column '$col_name': " new_val

# Trim spaces
new_val="${new_val#"${new_val%%[![:space:]]*}"}"
new_val="${new_val%"${new_val##*[![:space:]]}"}"

# If this column is PK, enforce NOT NULL and UNIQUE
if [[ $pk_col_index -ne -1 && $col_index -eq $pk_col_index ]]; then
    # Not null check
    if [[ -z "$new_val" ]]; then
        echo "Primary key value cannot be NULL or empty."
        exit 0
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
    done < "$data_file"

    if [[ $duplicate_found -eq 1 ]]; then
        echo "Another row already has primary key value '$new_val'. Update cancelled."
        exit 0
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
    exit 0
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
} < "$data_file" > "$data_file.tmp"

# Replace original table with updated version
mv "$data_file.tmp" "$data_file"

echo "Value updated successfully in table '$table'."

