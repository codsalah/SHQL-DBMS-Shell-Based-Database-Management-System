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

            # insert into <name>
            if [[ "$sw1" == "insert" && "$sw2" == "into" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: insert into <tbname>"
                    continue
                fi
                tbname="$3"
                cd "$db_path"
                "$DBMS_DIR/insert_into_tb.sh" "$tbname"
                cd "$DBMS_DIR"
                continue
            fi

            # delete from <name>
            if [[ "$sw1" == "delete" && "$sw2" == "from" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: delete from <tbname>"
                    continue
                fi
                tbname="$3"
                cd "$db_path"
                "$DBMS_DIR/delete_from_tb.sh" "$tbname"
                cd "$DBMS_DIR"
                continue
            fi

            # update table <name>
            if [[ "$sw1" == "update" && "$sw2" == "table" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: update table <tbname>"
                    continue
                fi
                tbname="$3"
                cd "$db_path"
                "$DBMS_DIR/update_tb.sh" "$tbname"
                cd "$DBMS_DIR"
                continue
            fi

            # select from <name>
            if [[ "$sw1" == "select" && "$sw2" == "from" ]]; then
                if [[ -z "$3" ]]; then
                    echo "Usage: select from <tbname>"
                    continue
                fi
                tbname="$3"
                cd "$db_path"
                "$DBMS_DIR/select_from_tb.sh" "$tbname"
                cd "$DBMS_DIR"
                continue
            fi

            # Unknown command inside DB context
            echo "Unknown command: $subline"
            echo "Supported commands inside '$dbname':"
            echo "  create table <name>"
            echo "  list tables"
            echo "  drop table <name>"
            echo "  insert into <name>"
            echo "  delete from <name>"
            echo "  update table <name>"
            echo "  select from <name>"
            echo "  back | exit"
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

