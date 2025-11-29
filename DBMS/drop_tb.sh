#!/usr/bin/bash

# Get the project folder path (parent directory of DBMS folder)
ProjectPath="$(dirname "$PWD")"

# Databases directory path
Databases="$ProjectPath/Databases"

# Make sure Databases folder exists
mkdir -p "$Databases"
attempt=0
while true 
do
	# Ask for database name to drop
	read -p "Enter the name of the table you want to drop (or 'exit' to return): " tableName

	# Trim leading spaces
	tableName="${tableName#"${tableName%%[![:space:]]*}"}"

	# Trim trailing spaces
	tableName="${tableName%"${tableName##*[![:space:]]}"}"

	# Check table name is not empty
	if [[ -z "$tableName" ]]; then
	    echo -e "\nTable name cannot be empty.\n"
	    continue
	fi

	# Check if user wants to exit
	if [[ "$tableName" == "exit" ]]; then
		echo -e "\nExiting drop table menu.\n"
		break
	fi

    # If table name ends with .meta tell it not to drop it
    if [[ "$tableName" == *.meta ]]; then
        echo -e "\nTable name cannot end with .meta.\n"
        continue
    fi


	# Check if table exists
	if [[ -f "./$tableName" ]]; then

	    read -p "Are you sure you want to delete '$tableName'? [y/N]: " ans

	    # Convert to lowercase
	    ans=$(echo "$ans" | tr 'A-Z' 'a-z')

	    # Check for y or yes
	    if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
		    rm "./$tableName"
            rm "./$tableName.meta"
		    echo -e "\nTable '$tableName' has been deleted.\n"
		    break
	    else
		    echo -e "\nDeletion cancelled.\n"
		    break
	    fi
	    continue
	else
	    echo -e "\nDrop canceled — table '$tableName' does not exist.\n"
		((attempt++))
		if [[ $attempt -ge 3 ]]; then
			echo -e "\nInvalid table name entered 3 times. Returning to menu.\n"
			break
		fi
	    continue
	fi
done
