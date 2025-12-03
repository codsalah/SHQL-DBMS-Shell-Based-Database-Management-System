#!/usr/bin/bash

# Default mode is CLI
MODE="cli"

# Parse command line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --gui)
            MODE="gui"
            ;;
        --cli)
            MODE="cli"
            ;;
        *)
            echo "Usage: $0 [--gui|--cli]"
            echo "  --gui : Use graphical interface (requires YAD)"
            echo "  --cli : Use command-line interface (default)"
            exit 1
            ;;
    esac
fi

# Export mode so child scripts can access it
export DBMS_MODE="$MODE"

# ---------------- CLI Mode ----------------
run_cli_mode() {
    while true; do
        echo -e "\n=========================================================================================="
        echo "                                  Main Menu - SHQL DBMS                                   "
        echo -e "==========================================================================================\n"

        PS3="Choose an Option: "
        select choice in "DBMS Menus" "Write Queries" "Exit"; do
            case "$REPLY" in
                1) 
                    if [ -f "./DBMS_menu.sh" ]; then
                        ./DBMS_menu.sh
                    else
                        echo "Error: DBMS_menu.sh not found!"
                    fi
                    break 
                    ;;
                2) 
                    if [ -f "./queries.sh" ]; then
                        ./queries.sh
                    else
                        echo "Error: queries.sh not found!"
                    fi
                    break 
                    ;;
                3) 
                    echo "Goodbye! Thank you for using SHQL DBMS."
                    exit 0 
                    ;;
                *) 
                    echo "Invalid choice"
                    ;;
            esac
        done
    done
}

# ---------------- GUI Mode ----------------
run_gui_mode() {
    # Source YAD utilities for reusable dialogs
    source "./yad_utilities.sh"
    
    while true; do
        # Prepare main dialog content
        local dialog_title="Database Management System"
        local dialog_message="<span font='23' weight='bold' foreground='#f59e0b'>   Welcome to Your SHQL DBMS</span>

        <span font='15' foreground='#059669'>Manage your SHQL Database with ease and efficiency</span>

        <span font='13' foreground='#6366f1'>Choose your path below to get started</span>"
        
        # Define buttons with icons and return codes
        main_buttons=(
            "<b>DBMS MENUS</b>!database:0" 
            "<b>WRITE QUERIES</b>!text-editor:1" 
            "<b>EXIT</b>!application-exit:2"
        )
        
        # Custom CSS for main dialog with left-aligned image
        local css_file="/tmp/yad_main_cat.css"
        cat > "$css_file" << 'EOF'
* { 
    background-color: #fffaf0; 
    color: #1f2937; 
    font-family: "Segoe UI", "Ubuntu", "Helvetica Neue", sans-serif; 
    font-size: 13pt; 
}

window, dialog, decoration { 
    background-color: #fffaf0; 
    border-radius: 18px; 
    padding: 20px; 
    box-shadow: 0 12px 40px rgba(0,0,0,0.15); 
}

/* Image positioned on the left */
image { 
    background-color: transparent; 
    margin-right: 20px;
    min-width: 150px;
    min-height: 150px;
    max-width: 150px;
    max-height: 150px;
}

label, text, textview { 
    background-color: #fffaf0; 
    color: #1f2937; 
    font-size: 14pt;
    line-height: 1.6em;
    padding: 8px;
}

/* Center all text elements */
label {
    justify-content: center;
    text-align: center;
}

text {
    text-align: center;
    justify-content: center;
}

/* Main title/heading text */
label:first-child {
    font-size: 18pt;
    font-weight: bold;
    color: #d97706;
    margin-bottom: 15px;
    text-align: center;
}

button { 
    background-image: linear-gradient(to bottom, #fbbf24, #f59e0b); 
    color: #ffffff; 
    font-weight: bold; 
    font-size: 14pt; 
    border-radius: 14px; 
    padding: 18px 40px; 
    margin: 8px;
    border: none; 
    box-shadow: 0 6px 25px rgba(245,158,11,0.4); 
    transition: all 0.3s ease; 
    min-width: 200px;
}

button:hover { 
    background-image: linear-gradient(to bottom, #fcd34d, #fbbf24); 
    box-shadow: 0 8px 30px rgba(245,158,11,0.55); 
    transform: translateY(-3px) scale(1.02); 
}

button:active {
    transform: translateY(-1px) scale(0.98);
    box-shadow: 0 4px 20px rgba(245,158,11,0.5);
}

button label { 
    background-color: transparent; 
    color: #ffffff;
    font-size: 14pt;
    font-weight: bold;
    text-shadow: 0 2px 4px rgba(0,0,0,0.2);
}
EOF

        # Build --button parameters dynamically
        local yad_buttons=()
        for b in "${main_buttons[@]}"; do
            yad_buttons+=(--button="$b")
        done

        # Check if cat.png exists, otherwise use fallback
        local logo_image="./cat.png"
        if [ ! -f "$logo_image" ]; then
            logo_image="database"
        fi

        # Show main dialog with cat logo on the left
        yad --title="$dialog_title" \
            --width=850 --height=600 --center --borders=30 \
            --text="$dialog_message" \
            --image="$logo_image" \
            --window-icon="$logo_image" \
            --no-escape --css="$css_file" \
            "${yad_buttons[@]}"
        
        ret=$?
        rm -f "$css_file"
        
        # Handle user choice
        case $ret in
            0)
                # Use DBMS Menus
                if [ -f "./DBMS_menu.sh" ]; then
                    ./DBMS_menu.sh
                else
                    show_error_dialog "DBMS_menu.sh not found!"
                fi
                ;;
            1)
                # Write Queries
                if [ -f "./queries.sh" ]; then
                    ./queries.sh
                else
                    show_error_dialog "queries.sh not found!"
                fi
                ;;
            2|252)
                # Exit or window closed
                show_goodbye_dialog
                exit 0
                ;;
            *)
                # Unknown error
                show_error_dialog "An unexpected error occurred. Please try again."
                ;;
        esac
    done
}

# ---------------- Main Entry ----------------
# Run the appropriate mode
if [ "$MODE" = "gui" ]; then
    run_gui_mode
else
    run_cli_mode
fi