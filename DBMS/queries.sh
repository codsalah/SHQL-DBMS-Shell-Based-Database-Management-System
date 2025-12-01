#!/usr/bin/bash

while true
do
    # Print empty line for spacing
    echo

    # Read a full command line from user
    read -p "DBMS> " line

    # Trim spaces
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # If the user just pressed Enter, skip
    if [[ -z "$line" ]]; then
        continue
    fi

    # Split the line
    set -- $line

    # Lowercase copies of first two words for case-insensitive matching
    w1="${1,,}"    # first word
    w2="${2,,}"    # second word

    # exit / quit
    if [[ "$w1" == "exit" || "$w1" == "quit" ]]; then
        echo "Leaving query mode..."
        break
    fi

    # create database <name>
    if [[ "$w1" == "create" && "$w2" == "database" ]]; then

        if [[ -z "$3" ]]; then
            echo "Usage: create database <dbname>"
            continue
        fi

        dbname="$3"

        ./create_db.sh "$dbname"   # create_db.sh handles messages
        continue
    fi

    # drop database <name>
    if [[ "$w1" == "drop" && "$w2" == "database" ]]; then

        if [[ -z "$3" ]]; then
            echo "Usage: drop database <dbname>"
            continue
        fi

        dbname="$3"

        ./drop_db.sh "$dbname"    # drop_db.sh handles confirm + messages
        continue
    fi

    # list databases
    if [[ "$w1" == "list" && "$w2" == "databases" ]]; then
        # Just call the list_dbs script (no args needed)
        ./list_dbs.sh              # or ./list_db.sh if that's your actual file name
        continue
    fi

    # add create_tb.sh
    if [[ "$w1" == "create" && "$w2" == "table" ]]; then

        if [[ -z "$3" ]]; then
            echo "Usage: create table <tbname>"
            continue
        fi

        tbname="$3"

        ./create_tb.sh "$tbname"
        continue
    fi

    # unknown query
    echo "Unknown or unsupported query: $line"
    echo "Supported now: create database <name>, drop database <name>, list databases, exit, quit"

done

