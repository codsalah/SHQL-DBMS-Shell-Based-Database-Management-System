#! /usr/bin/bash

while true       # Start an infinite loop so the menu keeps coming back
do
    echo -e "\n=========================================================================================="
    echo "                                       DBMS Menu                                          "
    echo -e "==========================================================================================\n"

    PS3="Choose an Option: "   # Prompt text for 'select'

    select choice in "Create Database" "List Databases" "Connect to Database" "Drop Database" "Exit"
    do
        case "$REPLY" in
            1)
                ./create_db.sh   # Run create_db.sh
                break
                ;;
            2)
                ./list_dbs.sh    # Run list_dbs.sh
                break
                ;;
            3)
                ./connect_db.sh  # Run connect_db.sh
                break
                ;;
            4)
                ./drop_db.sh     # Run drop_db.sh
                break
                ;;
            5)
                exit 0           # Exit the whole DBMS_menu script
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
done
