#!/usr/bin/bash

while true
do
    echo -e "\n=========================================================================================="
    echo "                           Welcome to your favourite DBMS ;D                                    "
    echo -e "==========================================================================================\n"

    PS3="Choose an Option: "

    select choice in "Use DBMS Menus" "Write Queries" "Exit"
    do
        case "$REPLY" in
            1)
                ./DBMS_menu.sh
                break
                ;;
            2)
                ./queries.sh
                break
                ;;
            3)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
done

