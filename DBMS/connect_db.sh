#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

# Capture the current directory (DBMS folder) to call scripts later
DBMS_DIR="$PWD"

while true
do
	# Ask for database name to drop
	read -p "Enter the name of the database you want to connect: " name

	# Trim leading spaces
	name="${name#"${name%%[![:space:]]*}"}"

	# Trim trailing spaces
	name="${name%"${name##*[![:space:]]}"}"

	# Check if empty name
	if [[ -z "$name" ]]; then
	    echo -e "\nDatabase name cannot be empty.\n"
	    continue
	fi

	# Check if directory exists inside Databases
	if [[ -d "$Databases/$name" ]]; then
	    cd $Databases/$name
	    echo -e "\n=========================================================================================="
	    echo "                                    Connected to $name                                    "
	    echo -e "==========================================================================================\n"
	    
	    PS3="Choose an Option: "

	    select choice in "Create Table" "List Table" "Drop Table" "Insert into Table" "Delete from Table" "Update Table" "Select from Table" "Back to DBMS Menu"
		    do
			    case "$REPLY" in
		    	    1) "$DBMS_DIR/create_tb.sh" ;;
		    	    2) "$DBMS_DIR/list_tb.sh" ;;
		    	    3) "$DBMS_DIR/drop_tb.sh" ;;
		    	    4) "$DBMS_DIR/insert_into_tb.sh" ;;
		    	    5) "$DBMS_DIR/delete_from_tb.sh" ;;
		    	    6) "$DBMS_DIR/update_tb.sh" ;;
		    	    7) "$DBMS_DIR/select_from_tb.sh" ;;
		    	    8) exit 0 ;;
		    	    *) echo "Invalid choice" ;;
		    	    esac
		    done
	break
	else
	    echo -e "\nConnection canceled — database '$name' does not exist.\n"
	    continue
	fi
done
