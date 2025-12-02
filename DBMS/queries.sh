#!/usr/bin/bash

# Where project and Databases live
ProjectPath="$(dirname "$PWD")"
Databases="$ProjectPath/Databases"

# Where all DBMS scripts live (this directory)
DBMS_DIR="$PWD"

while true
do
    echo

    # Top-level prompt (no specific DB)
    read -p "DBMS> " line

    # Trim leading spaces
    line="${line#"${line%%[![:space:]]*}"}"
    # Trim trailing spaces
    line="${line%"${line##*[![:space:]]}"}"

    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi

    # Split into $1, $2, $3, ...
    set -- $line

    # Lowercase for matching
    w1="${1,,}"
    w2="${2,,}"

    # ===================== GLOBAL COMMANDS =====================

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
        ./create_db.sh "$dbname"
        continue
    fi

    # drop database <name>
    if [[ "$w1" == "drop" && "$w2" == "database" ]]; then
        if [[ -z "$3" ]]; then
            echo "Usage: drop database <dbname>"
            continue
        fi
        dbname="$3"
        ./drop_db.sh "$dbname"
        continue
    fi

    # list databases
    if [[ "$w1" == "list" && "$w2" == "databases" ]]; then
        ./list_dbs.sh
        continue
    fi

    # ===================== use <database> =====================

    if [[ "$w1" == "use" ]]; then
        if [[ -z "$2" ]]; then
            echo "Usage: use <dbname>"
            continue
        fi

        dbname="$2"

        # Check database exists
        if [[ ! -d "$Databases/$dbname" ]]; then
            echo "Database '$dbname' does not exist."
            continue
        fi

        echo "You are now connected to '$dbname'."
        db_path="$Databases/$dbname"

        # --------- INNER LOOP: commands INSIDE this database ---------
        while true
        do
            echo
            read -p "DBMS[$dbname]> " subline

            # Trim spaces
            subline="${subline#"${subline%%[![:space:]]*}"}"
            subline="${subline%"${subline##*[![:space:]]}"}"

            # Skip empty lines
            if [[ -z "$subline" ]]; then
                continue
            fi

            # Split into $1, $2, $3, ...
            set -- $subline

            sw1="${1,,}"
            sw2="${2,,}"

            # ---- leave this database session ----
            if [[ "$sw1" == "back" || "$sw1" == "exit" || "$sw1" == "quit" ]]; then
                echo "Leaving database '$dbname'."
                break
            fi

            # ================= TABLE COMMANDS (ONLY HERE) =================
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

            # add truncate table
	    if [[ "$sw1" == "truncate" && "$sw2" == "table" ]]; then
    	    (
            	cd "$db_path" || exit 1

        	    # If user typed: truncate table mytable
        	    if [[ -n "$3" ]]; then
            	    tableName="$3"
            	    "$DBMS_DIR/truncate_tb.sh" "$tableName"
            	    else
            	    # No table name given -> let truncate_tb.sh ask for it
            	    "$DBMS_DIR/truncate_tb.sh"
        	    fi
    	    )
    	    continue
	    fi

            # add insert into table
            if [[ "$sw1" == "insert" && "$sw2" == "into" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: INSERT INTO <table> VALUES (...)" 
                    continue
                fi

                tbl="$3"

                # Rebuild the rest of the line starting from $4
                rest="${*:4}"
                # Trim spaces
                rest="${rest#"${rest%%[![:space:]]*}"}"

                # First word should be VALUES (any case)
                first_word="${rest%%[[:space:]]*}"
                if [[ "${first_word,,}" != "values" ]]; then
                    echo "Syntax error: expected VALUES keyword after table name."
                    continue
                fi

                # Remove the VALUES keyword
                values_part="${rest#"$first_word"}"
                # Trim spaces
                values_part="${values_part#"${values_part%%[![:space:]]*}"}"

                # Expect parentheses around values
                if [[ ${values_part:0:1} != "(" || ${values_part: -1} != ")" ]]; then
                    echo "Syntax error: expected parentheses around values."
                    continue
                fi

                # Strip surrounding parentheses
                inner="${values_part:1:${#values_part}-2}"   # inside (...)

                # Split by comma into raw values
                IFS=',' read -ra raw_values <<< "$inner"

                cleaned_values=()
                for v in "${raw_values[@]}"; do
                    # Trim spaces
                    v="${v#"${v%%[![:space:]]*}"}"
                    v="${v%"${v##*[![:space:]]}"}"

                    # Remove surrounding single quotes if present
                    if [[ ${#v} -ge 2 && ${v:0:1} == "'" && ${v: -1} == "'" ]]; then
                        v="${v:1:${#v}-2}"
                    fi

                    cleaned_values+=("$v")
                done

                # Call insert_into_tb.sh with table and values
                (
                    cd "$db_path" || exit 1
                    "$DBMS_DIR/insert_into_tb.sh" "$tbl" "${cleaned_values[@]}"
                )
                continue
            fi

        done

        # done with this database session, go back to outer loop
        continue
    fi

    # ================= UNKNOWN TOP-LEVEL COMMAND =================
    
    # unknown query
    echo "Unknown or unsupported query: $line"
    echo "Top-level supported:"
    echo "  create database <name>"
    echo "  drop database <name>"
    echo "  list databases"
    echo "  use <name>"
    echo "  exit | quit"

done

