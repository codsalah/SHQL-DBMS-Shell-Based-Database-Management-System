#!/usr/bin/bash

# Where project and Databases live
ProjectPath="$(dirname "$PWD")"
Databases="$ProjectPath/Databases"

# Where all DBMS scripts live (this directory)
DBMS_DIR="$PWD"

# Source the select_from_tb.sh script so we can use its functions
source "$DBMS_DIR/select_from_tb.sh"

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
            set -f
            set -- $subline
            set +f

            sw1="${1,,}"
            sw2="${2,,}"

            # ---- leave this database session ----
            if [[ "$sw1" == "back" || "$sw1" == "exit" || "$sw1" == "quit" ]]; then
                echo "Leaving database '$dbname'."
                break
            fi

            # ================= TABLE COMMANDS (ONLY HERE) =================

            # create table <name>
            if [[ "$sw1" == "create" && "$sw2" == "table" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: create table <tbname>"
                    continue
                fi
                tbname="$3"
                # Switch to DB directory so table files are created there
                cd "$db_path"
                "$DBMS_DIR/create_tb.sh" "$tbname"
                # Switch back to DBMS directory
                cd "$DBMS_DIR"
                continue
            fi

            # list tables
            if [[ "$sw1" == "list" && "$sw2" == "tables" ]]; then
                cd "$db_path"
                "$DBMS_DIR/list_tb.sh"
                cd "$DBMS_DIR"
                continue
            fi

            # drop table <name>
            if [[ "$sw1" == "drop" && "$sw2" == "table" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: drop table <tbname>"
                    continue
                fi
                tbname="$3"
                cd "$db_path"
                "$DBMS_DIR/drop_tb.sh" "$tbname"
                cd "$DBMS_DIR"
                continue
            fi

            # truncate table <name>
            if [[ "$sw1" == "truncate" && "$sw2" == "table" ]]; then
                (
                    cd "$db_path" || exit 1
                    if [[ -n "$3" ]]; then
                        tableName="$3"
                        "$DBMS_DIR/truncate_tb.sh" "$tableName"
                    else
                        "$DBMS_DIR/truncate_tb.sh"
                    fi
                )
                continue
            fi

            # insert into table
            if [[ "$sw1" == "insert" && "$sw2" == "into" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: INSERT INTO <table> VALUES (...)" 
                    continue
                fi

                tbl="$3"
                rest="${*:4}"
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

                if [[ ${values_part:0:1} != "(" || ${values_part: -1} != ")" ]]; then
                    echo "Syntax error: expected parentheses around values."
                    continue
                fi

                inner="${values_part:1:${#values_part}-2}"   # inside (...)

                # Split by comma into raw values
                IFS=',' read -ra raw_values <<< "$inner"

                cleaned_values=()
                for v in "${raw_values[@]}"; do
                    v="${v#"${v%%[![:space:]]*}"}"
                    v="${v%"${v##*[![:space:]]}"}"
                    if [[ ${#v} -ge 2 && ${v:0:1} == "'" && ${v: -1} == "'" ]]; then
                        v="${v:1:${#v}-2}"
                    fi
                    cleaned_values+=("$v")
                done

                (
                    cd "$db_path" || exit 1
                    "$DBMS_DIR/insert_into_tb.sh" "$tbl" "${cleaned_values[@]}"
                )
                continue
            fi

            # ================= DELETE FROM <table> WHERE <condition> =================
            if [[ "$sw1" == "delete" && "$sw2" == "from" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: DELETE FROM <table> WHERE <column> <operator> <value>"
                    continue
                fi

                tbl="$3"
                
                # Check if table exists
                if [[ ! -f "$db_path/$tbl" ]]; then
                    echo "Table '$tbl' does not exist."
                    continue
                fi

                # Rebuild the rest: should be "WHERE column operator value"
                rest="${*:4}"
                rest="${rest#"${rest%%[![:space:]]*}"}"

                # Check if WHERE clause exists
                first_word="${rest%%[[:space:]]*}"
                if [[ "${first_word,,}" != "where" ]]; then
                    echo "Syntax error: expected WHERE clause."
                    echo "Usage: DELETE FROM <table> WHERE <column> <operator> <value>"
                    continue
                fi

                # Parse: WHERE column operator value
                read -ra where_parts <<< "$rest"
                
                if [[ ${#where_parts[@]} -lt 4 ]]; then
                    echo "Syntax error: WHERE clause must be: WHERE <column> <operator> <value>"
                    continue
                fi

                # Call delete_from_tb.sh with SQL-like syntax
                (
                    cd "$db_path" || exit 1
                    "$DBMS_DIR/delete_from_tb.sh" "$tbl" "${where_parts[@]}"
                )
                continue
            fi

            # ================= UPDATE <table> SET <assignments> WHERE <condition> =================
            if [[ "$sw1" == "update" ]]; then
                if [[ -z "$2" ]]; then
                    echo "Usage: UPDATE <table> SET <col1>=<val1>,<col2>=<val2> WHERE <column> <operator> <value>"
                    continue
                fi

                tbl="$2"
                
                # Check if table exists
                if [[ ! -f "$db_path/$tbl" ]]; then
                    echo "Table '$tbl' does not exist."
                    continue
                fi

                # Rebuild rest: should be "SET ... WHERE ..."
                rest="${*:3}"
                rest="${rest#"${rest%%[![:space:]]*}"}"

                # Check for SET keyword
                first_word="${rest%%[[:space:]]*}"
                if [[ "${first_word,,}" != "set" ]]; then
                    echo "Syntax error: expected SET keyword."
                    echo "Usage: UPDATE <table> SET <col1>=<val1>,... WHERE <column> <operator> <value>"
                    continue
                fi

                # Call update_tb.sh with SQL-like syntax: table SET assignments WHERE condition
                (
                    cd "$db_path" || exit 1
                    "$DBMS_DIR/update_tb.sh" "$tbl" "${*:3}"
                )
                continue
            fi

            # ===================== SQL-Like Queries =====================

            # select all from <table name> where <pk column name> = <value>
            if [[ "$sw1" == "select" && "$sw2" == "all" && "${3,,}" == "from" && "${5,,}" == "where" ]]; then
                if [[ -z "$6" || -z "$8" ]]; then
                    echo "Usage: select all from <table_name> where <column_name> = <value>"
                    continue
                fi
                tbl="$4"
                column_name="$6"
                value="$8"
                # In this case, call select function (needs to be defined based on your requirements)
                select_by_pk "$db_path/$tbl" "$column_name" "$value"
                continue
            fi

            # select <column name>,<column name> from <table name>
	    if [[ "$sw1" == "select" && "$sw2" != "all" && "${3,,}" == "from" ]]; then
    	    	if [[ -z "$4" ]]; then
        	    echo "Usage: select <column_names> from <table_name>"
        	    continue
    		fi
    
    	        tbl="$4"  # Table name is the 4th argument
    	        columns="$2"  # Column names (comma-separated) are the first argument
    
    	        # Remove commas and prepare for the column selection
    	        column_names="${columns//,/ }"
    
    	        # Call select_specific_columns with the full table path and column names
    	        select_specific_columns "$db_path/$tbl" "$column_names"
    	        continue
	    fi


            # select all from <table name>
            if [[ "$sw1" == "select" && "$sw2" == "all" && "${3,,}" == "from" ]]; then
                if [[ -z "$4" ]]; then
                    echo "Usage: select all from <table_name>"
                    continue
                fi
                tbl="$4"
                select_all "$db_path/$tbl"
                continue
            fi

            # ================= UNKNOWN COMMAND =================
            echo "Unknown command: $subline"
            echo "Supported commands inside '$dbname':"
            echo "  create table <name>"
            echo "  list tables"
            echo "  drop table <name>"
            echo "  truncate table <name>"
            echo "  insert into <table> values (...)"
            echo "  delete from <table> where <col> <op> <val>"
            echo "  update <table> set <col>=<val> where <col> <op> <val>"
            echo "  back | exit"
        done

        # done with this database session, go back to outer loop
        continue
    fi

    # ================= UNKNOWN TOP-LEVEL COMMAND =================
    echo "Unknown or unsupported query: $line"
    echo "Top-level supported:"
    echo "  create database <name>"
    echo "  drop database <name>"
    echo "  list databases"
    echo "  use <name>"
    echo "  exit | quit"

done

