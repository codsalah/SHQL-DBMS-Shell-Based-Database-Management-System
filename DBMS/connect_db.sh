#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

# Capture the current directory (DBMS folder) to call scripts later
DBMS_DIR="$PWD"

# Source YAD utility functions
source "./yad_utilities.sh"

while true
do
    if [ "$DBMS_MODE" = "gui" ]; then
        # GUI Mode: Select Database
        db_options=()
        for db in "$Databases"/*; do
            if [[ -d "$db" ]]; then
                db_name=$(basename "$db")
                db_options+=("database" "$db_name" "Database")
            fi
        done
        
        if [ ${#db_options[@]} -eq 0 ]; then
            show_info_dialog "Connect Database" "No databases available to connect."
            break
        fi

        name=$(show_options "Connect Database" "Select a database to connect:" "${db_options[@]}")
        if [ $? -ne 0 ] || [ -z "$name" ]; then
            break # Cancelled
        fi
    else
        # CLI Mode: Ask for name
        read -p "Enter the name of the database you want to connect: " name
    fi

	# Trim leading spaces
	name="${name#"${name%%[![:space:]]*}"}"

	# Trim trailing spaces
	name="${name%"${name##*[![:space:]]}"}"

	# Check if empty name
	if [[ -z "$name" ]]; then
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Database name cannot be empty."
        else
    	    echo -e "\nDatabase name cannot be empty.\n"
        fi
	    continue
	fi

	# Check if directory exists inside Databases
	if [[ -d "$Databases/$name" ]]; then
	    cd "$Databases/$name"
        
        if [ "$DBMS_MODE" = "gui" ]; then
            show_info_dialog "Connected" "Successfully connected to '$name'"
            
            # GUI Table Menu Loop
            while true; do
                table_options=(
                    "document-new" "Create Table" "Create a new table"
                    "view-list" "List Tables" "View all tables"
                    "edit-delete" "Drop Table" "Delete a table"
                    "list-add" "Insert into Table" "Add data to table"
                    "edit-cut" "Delete from Table" "Remove data from table"
                    "view-refresh" "Update Table" "Modify data in table"
                    "system-search" "Select from Table" "Query data from table"
                    "edit-clear" "Truncate Table" "Empty a table" 
                )
                
                choice=$(show_options "Table Menu: $name" "Select an operation:" "${table_options[@]}")
                ret=$?
                
                if [ $ret -ne 0 ] || [ -z "$choice" ]; then
                    break # Back to DB menu
                fi
                
                case "$choice" in
                    "Create Table") "$DBMS_DIR/create_tb.sh" ;;
                    "List Tables") "$DBMS_DIR/list_tb.sh" ;;
                    "Drop Table") "$DBMS_DIR/drop_tb.sh" ;;
                    "Insert into Table") "$DBMS_DIR/insert_into_tb.sh" ;;
                    "Delete from Table") "$DBMS_DIR/delete_from_tb.sh" ;;
                    "Update Table") "$DBMS_DIR/update_tb.sh" ;;
                    "Select from Table") "$DBMS_DIR/select_from_tb.sh" ;;
                    "Truncate Table") "$DBMS_DIR/truncate_tb.sh" ;;
                esac
            done
            
            # After breaking from table menu, go back to DB selection (outer loop)
            # or break completely? CLI breaks completely.
            # "break" here breaks the outer loop, returning to main menu.
            break 
        else
    	    echo -e "\n=========================================================================================="
    	    echo "                                    Connected to $name                                    "
    	    echo -e "==========================================================================================\n"
    	    
    	    PS3="Choose an Option to perform on connected database: "

    	    select choice in "Create Table" "List Table" "Drop Table" "Insert into Table" "Delete from Table" "Update Table" "Select from Table" "Truncate Table" "Sort Index Search" "Back to DBMS Menu"
    		    do
    			    case "$REPLY" in
    		    	    1) "$DBMS_DIR/create_tb.sh" ;;
    		    	    2) "$DBMS_DIR/list_tb.sh" ;;
    		    	    3) "$DBMS_DIR/drop_tb.sh" ;;
    		    	    4) "$DBMS_DIR/insert_into_tb.sh" ;;
    		    	    5) "$DBMS_DIR/delete_from_tb.sh" ;;
    		    	    6) "$DBMS_DIR/update_tb.sh" ;;
    		    	    7) "$DBMS_DIR/select_from_tb.sh" ;;
    		   			8) "$DBMS_DIR/truncate_tb.sh" ;;
    					9) "$DBMS_DIR/sort_index_search.sh" ;;
    					10) exit 0 ;;
    		    	    *) echo "Invalid choice" ;;
    		    	    esac
    		    done
    	    break
        fi
	else
        if [ "$DBMS_MODE" = "gui" ]; then
            show_error_dialog "Connection canceled — database '$name' does not exist."
        else
    	    echo -e "\nConnection canceled — database '$name' does not exist.\n"
        fi
	    continue
	fi
done
