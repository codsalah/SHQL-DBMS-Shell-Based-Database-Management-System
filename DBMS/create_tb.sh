#!/usr/bin/bash

# Function to validate table name
validate_name() {
    if [[ ! $1 =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        echo "Invalid name. Must start with a letter and contain only alphanumeric characters and underscores."
        return 1
    fi
    return 0
}

# Check if argument is provided
tableName="$1"

while true; do
    # If tableName is not set (not passed as arg or reset due to error), ask for it
    if [[ -z "$tableName" ]]; then
        read -p "Enter Table Name: " tableName < /dev/tty
    fi
    
    # Check if empty
    if [[ -z "$tableName" ]]; then
        echo "Table name cannot be empty."
        tableName=""
        continue
    fi

    # Validate name format
    if ! validate_name "$tableName"; then
        tableName=""
        continue
    fi

    # Check if table already exists
    if [[ -f "$tableName" ]]; then
        echo "Table '$tableName' already exists."
        tableName=""
        continue
    fi
    
    break
done

while true; do
    read -p "Enter Number of Columns: " colsNum < /dev/tty
    if [[ ! "$colsNum" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid number. Please enter a positive integer."
        continue
    fi
    break
done

# Initialize metadata content
metaData=""
# Initialize primary key flag
pkSet=false

for (( i=1; i<=colsNum; i++ ))
do
    echo "---------------- Column $i ----------------"
    
    # Get Column Name
    while true; do
        read -p "Enter Name of Column $i: " colName < /dev/tty
        if [[ -z "$colName" ]]; then
            echo "Column name cannot be empty."
            continue
        fi
        if ! validate_name "$colName"; then
            continue
        fi
        
        # Check for duplicate column names in current definition
        if [[ "$metaData" == *"$colName"* ]]; then
            echo "Column name '$colName' already used."
            continue
        fi
        # finished all test cases then break
        break
    done

    # Get Column Type
    while true; do
        echo "Select Type of Column $i:"
        PS3="Choose type (1 or 2): "
        select type in "int" "string"
        do
            case $type in
                int|string) 
                    colType=$type
                    break 2
                    ;;
                *) echo "Invalid choice. Please select 1 or 2." ;;
            esac
        done
    done

    # Set Primary Key
    isPK=""
    if [ "$pkSet" = false ]; then
        while true; do
            read -p "Make '$colName' the Primary Key? (y/n): " pkChoice < /dev/tty
            pkChoice=$(echo "$pkChoice" | tr 'A-Z' 'a-z')
            case $pkChoice in
                y|yes) 
                    isPK=":PK"
                    pkSet=true
                    echo "Primary key set to '$colName'."
                    break
                    ;;
                n|no) 
                    break 
                    ;;
                *) echo "Please answer yes or no." ;;
            esac
        done
    fi

    # Append to metadata
    if [ $i -eq 1 ]; then
        metaData="${colName}:${colType}${isPK}"
    else
        metaData="${metaData}|${colName}:${colType}${isPK}"
    fi
done

# Create table files and write metadata
echo "$metaData" > "$tableName.meta"

# Extract column names and write as header row in table file
# Parse metadata to get just the column names
IFS='|' read -ra columns <<< "$metaData"
header=""
for col in "${columns[@]}"; do
    IFS=':' read -ra parts <<< "$col"
    col_name="${parts[0]}"
    
    if [[ -z "$header" ]]; then
        header="$col_name"
    else
        header="$header|$col_name"
    fi
done

# Write header to table file
echo "$header" > "$tableName"

echo -e "\nTable '$tableName' created successfully!"
echo "Schema: $metaData"
