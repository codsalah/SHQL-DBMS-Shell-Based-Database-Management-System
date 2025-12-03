#!/usr/bin/bash

# Source YAD utility functions
source "./yad_utilities.sh"

# ---------------- CLI Mode ----------------
run_cli_menu() {
    while true; do
        echo -e "\n=========================================================================================="
        echo "                                       DBMS Menu                                          "
        echo -e "==========================================================================================\n"

        PS3="Choose an Option: "
        select choice in "Create Database" "List Databases" "Connect to Database" "Drop Database" "Back to Main Menu"; do
            case "$REPLY" in
                1) ./create_db.sh; break ;;
                2) ./list_dbs.sh; break ;;
                3) ./connect_db.sh; break ;;
                4) ./drop_db.sh; break ;;
                5) return 0 ;;  # Return to main menu
                *) echo "Invalid choice";;
            esac
        done
    done
}

# ---------------- GUI Mode ----------------
run_gui_menu() {
    while true; do
        # ---------------- Show DBMS Options Dialog ----------------
        # Build options list for DBMS operations
        options_list=(
            "database-new" "Create Database" "Create a new database"
            "view-list" "List Databases" "View all existing databases"
            "network-connect" "Connect to Database" "Connect to an existing database"
            "edit-delete" "Drop Database" "Delete a database permanently"
        )
        
        selected_option=$(show_options "🗄️ DBMS Menu" "Select an operation to perform on your databases:" "${options_list[@]}")
        opt_ret=$?

        # Handle Back / Close - Return to main menu
        if [ $opt_ret -ne 0 ] || [ -z "$selected_option" ]; then
            return 0
        fi

        # ---------------- Execute Selected Option ----------------
        case "$selected_option" in
            "Create Database") 
                if [ -f "./create_db.sh" ]; then
                    ./create_db.sh
                else
                    show_error_dialog "create_db.sh not found!"
                fi
                ;;
            "List Databases") 
                if [ -f "./list_dbs.sh" ]; then
                    ./list_dbs.sh
                else
                    show_error_dialog "list_dbs.sh not found!"
                fi
                ;;
            "Connect to Database") 
                if [ -f "./connect_db.sh" ]; then
                    ./connect_db.sh
                else
                    show_error_dialog "connect_db.sh not found!"
                fi
                ;;
            "Drop Database") 
                if [ -f "./drop_db.sh" ]; then
                    ./drop_db.sh
                else
                    show_error_dialog "drop_db.sh not found!"
                fi
                ;;
            *)
                if [ -n "$selected_option" ]; then
                    show_error_dialog "Invalid selection: $selected_option\nPlease try again."
                fi
                ;;
        esac
    done
}

# ---------------- Main Entry ----------------
if [ "$DBMS_MODE" = "gui" ]; then
    run_gui_menu
else
    run_cli_menu
fi