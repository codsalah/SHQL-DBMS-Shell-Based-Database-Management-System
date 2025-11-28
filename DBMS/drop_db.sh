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
	read -p "Enter the name of the database you want to drop: " name

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

	    read -p "Are you sure you want to delete '$name'? [y/N]: " ans

	    # Convert to lowercase
	    ans=$(echo "$ans" | tr 'A-Z' 'a-z')

	    # Check for y or yes
	    if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
		rm -r "$Databases/$name"
		echo -e "\nDatabase '$name' has been deleted.\n"
		break
	    else
		echo -e "\nDeletion cancelled.\n"
		break
	    fi
	    continue
	else
	    echo -e "\nDrop canceled — database '$name' does not exist.\n"
	    continue
	fi
done
