#!/usr/bin/bash

while true
do

  read -p "Enter table name: " tableName < /dev/tty

  # Trim leading spaces
  tableName="${tableName#"${tableName%%[![:space:]]*}"}"

  # Trim trailing spaces
  tableName="${tableName%"${tableName##*[![:space:]]}"}"

  # Check empty name
  if [[ -z "$tableName" ]]; then
    echo "Table name can't be empty or only spaces."
    continue
  fi

  # Check invalid characters
  if [[ "$tableName" =~ [^a-zA-Z0-9_] ]]; then
    echo "INVALID NAME!! Use only letters, numbers, and underscores."
    continue
  fi

  # Check if table already exists
  if [[ -d "./$tableName" ]]; then
    echo "Table '$tableName' already exists."
    continue
  fi

  # Create the database
  if [[ "$tableName" =~ ^[a-zA-Z] ]]; then
    touch "./$tableName"
    touch "./$tableName.meta"
    echo "Table '$tableName' created successfully."
    echo "Table '$tableName' metadata created successfully."
    break
  else
    echo "INVALID NAME!! Start the table name with a letter."
    continue
  fi
done
