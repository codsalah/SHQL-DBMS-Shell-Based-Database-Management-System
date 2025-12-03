#!/usr/bin/bash

# Source YAD utility functions
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/yad_utilities.sh"

# Function to validate table name
validate_name() {
    if [[ ! $1 =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        return 1
    fi
    return 0
}

# Function to show error message based on mode
show_error() {
    local message="$1"
    if [ "$DBMS_MODE" = "gui" ]; then
        show_error_dialog "$message"
    else
        echo "$message"
    fi
}

# Function to show success message based on mode
show_success() {
    local message="$1"
    if [ "$DBMS_MODE" = "gui" ]; then
        show_info_dialog "Success" "$message"
    else
        echo -e "\n$message"
    fi
}

# Check if argument is provided
tableName="$1"

while true; do
    # If tableName is not set (not passed as arg or reset due to error), ask for it
    if [[ -z "$tableName" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            tableName=$(show_entry_dialog "Create Table" "Enter Table Name:" "")
            if [ $? -ne 0 ]; then
                exit 1
            fi
        else
            read -p "Enter Table Name: " tableName < /dev/tty
        fi
    fi
    
    # Trim spaces
    tableName="${tableName#"${tableName%%[![:space:]]*}"}"
    tableName="${tableName%"${tableName##*[![:space:]]}"}"
    
    # Check if empty
    if [[ -z "$tableName" ]]; then
        show_error "Table name cannot be empty."
        tableName=""
        continue
    fi

    # Validate name format
    if ! validate_name "$tableName"; then
        show_error "Invalid name. Must start with a letter and contain only alphanumeric characters and underscores."
        tableName=""
        continue
    fi

    # Check if table already exists
    if [[ -f "$tableName" ]]; then
        show_error "Table '$tableName' already exists."
        tableName=""
        continue
    fi
    
    break
done

# Check if we have extra arguments (Non-interactive mode)
if [[ -n "$2" ]]; then
    if [[ "${2,,}" == "columns" ]]; then
        # Non-interactive mode with schema definition
        # Syntax: create_tb.sh <tableName> columns (col1:type1:pk,col2:type2)
        
        # Reconstruct the columns definition from arguments
        shift 2
        args="$*"
        
        # Trim spaces
        args="${args#"${args%%[![:space:]]*}"}"
        args="${args%"${args##*[![:space:]]}"}"
        
        # Check for parentheses
        if [[ "${args:0:1}" != "(" || "${args: -1}" != ")" ]]; then
            show_error "Error: Columns definition must be enclosed in parentheses.\nUsage: create table <tableName> columns (col1:type:pk,col2:type)"
            exit 1
        fi
        
        # Remove parentheses
        content="${args:1:${#args}-2}"
        
        # Split by comma
        IFS=',' read -ra col_defs <<< "$content"
        
        metaData=""
        header=""
        
        for col_def in "${col_defs[@]}"; do
            # Trim spaces
            col_def="${col_def#"${col_def%%[![:space:]]*}"}"
            col_def="${col_def%"${col_def##*[![:space:]]}"}"
            
            # Parse col:type:pk
            IFS=':' read -ra parts <<< "$col_def"
            
            col_name="${parts[0]}"
            col_type="${parts[1]}"
            is_pk="${parts[2]}" # optional
            
            # Validate name
            if ! validate_name "$col_name"; then
                show_error "Invalid column name '$col_name'."
                exit 1
            fi
            
            # Validate type
            if [[ "$col_type" != "int" && "$col_type" != "string" ]]; then
                show_error "Invalid type '$col_type' for column '$col_name'. Supported types: int, string."
                exit 1
            fi
            
            # Normalize PK
            pk_str=""
            if [[ "${is_pk,,}" == "pk" ]]; then
                pk_str=":PK"
            fi
            
            # Build metadata part
            meta_part="${col_name}:${col_type}${pk_str}"
            
            if [[ -z "$metaData" ]]; then
                metaData="$meta_part"
                header="$col_name"
            else
                metaData="$metaData|$meta_part"
                header="$header|$col_name"
            fi
        done
        
        # Create table files
        echo "$metaData" > "$tableName.meta"
        echo "$header" > "$tableName"
        
        show_success "Table '$tableName' created successfully!\nSchema: $metaData"
        exit 0
    else
        # Arguments provided but not 'columns'
        show_error "Invalid syntax.\nUsage: create table <tableName> [columns (col1:type:pk, ...)]"
        exit 1
    fi
fi

# Interactive Mode (GUI or CLI)

while true; do
    if [ "$DBMS_MODE" = "gui" ]; then
        colsNum=$(show_entry_dialog "Create Table" "Enter Number of Columns:" "")
        if [ $? -ne 0 ]; then
            exit 1
        fi
    else
        read -p "Enter Number of Columns: " colsNum
    fi
    
    if [[ ! "$colsNum" =~ ^[1-9][0-9]*$ ]]; then
        show_error "Invalid number. Please enter a positive integer."
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
    if [ "$DBMS_MODE" != "gui" ]; then
        echo "---------------- Column $i ----------------"
    fi
    
    # Get Column Name
    while true; do
        if [ "$DBMS_MODE" = "gui" ]; then
            colName=$(show_entry_dialog "Column $i" "Enter Name of Column $i:" "")
            if [ $? -ne 0 ]; then
                exit 1
            fi
        else
            read -p "Enter Name of Column $i: " colName
        fi
        
        # Trim spaces
        colName="${colName#"${colName%%[![:space:]]*}"}"
        colName="${colName%"${colName##*[![:space:]]}"}"
        
        if [[ -z "$colName" ]]; then
            show_error "Column name cannot be empty."
            continue
        fi
        if ! validate_name "$colName"; then
            show_error "Invalid column name. Must start with a letter and contain only alphanumeric characters and underscores."
            continue
        fi
        
        # Check for duplicate column names in current definition
        if [[ "$metaData" == *"$colName"* ]]; then
            show_error "Column name '$colName' already used."
            continue
        fi
        break
    done

    # Get Column Type
    if [ "$DBMS_MODE" = "gui" ]; then
        # Use show_options for type selection
        type_options=(
            "dialog-information" "int" "Integer type"
            "dialog-information" "string" "String type"
        )
        colType=$(show_options "Column Type" "Select Type for Column '$colName':" "${type_options[@]}")
        if [ $? -ne 0 ]; then
            exit 1
        fi
        # Remove any extra whitespace/newlines
        colType=$(echo "$colType" | tr -d '\n' | xargs)
    else
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
    fi

    # Set Primary Key
    isPK=""
    if [ "$pkSet" = false ]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            if show_question_dialog "Make '$colName' the Primary Key?"; then
                isPK=":PK"
                pkSet=true
            fi
        else
            while true; do
                read -p "Make '$colName' the Primary Key? (y/n): " pkChoice
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

show_success "Table '$tableName' created successfully!\nSchema: $metaData"
