#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"

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
		    	    1) ./create_tb.sh ;;
		    	    2) ./list_tb.sh ;;
		    	    3) ./drop_tb.sh ;;
		    	    4) ./insert_into_tb.sh ;;
		    	    5) ./delete_from_tb.sh ;;
		    	    6) ./update_tb.sh ;;
		    	    7) ./select_from_tb.sh ;;
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
