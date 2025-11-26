#!/usr/bin/bash

Databases="$(dirname "$PWD")/Databases"

mkdir -p "$Databases"

while true
do

  read -p "Enter database name: " db

  # Trim leading spaces
  db="${db#"${db%%[![:space:]]*}"}"

  # Trim trailing spaces
  db="${db%"${db##*[![:space:]]}"}"

  # Check empty name
  if [[ -z "$db" ]]; then
    echo "Database name can't be empty or only spaces."
    continue
  fi

  # Check invalid characters
  if [[ "$db" =~ [^a-zA-Z0-9_] ]]; then
    echo "INVALID NAME!! Use only letters, numbers, and underscores."
    continue
  fi

  # Check if database already exists
  if [[ -d "$Databases/$db" ]]; then
    echo "Database '$db' already exists."
    continue
  fi

  # Create the database
  if [[ "$db" =~ ^[a-zA-Z] ]]; then
    mkdir "$Databases/$db"
    echo "Database '$db' created successfully."
    break
  else
    echo "INVALID NAME!! Start the database name with a letter."
    continue
  fi
done
