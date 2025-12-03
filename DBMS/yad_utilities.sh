#!/usr/bin/bash

# ============================================================================
# REUSABLE GENERAL YAD DIALOG FUNCTIONS and UTILITIES
# ============================================================================

# ---------------- Main / Start Dialog ----------------
show_main_dialog() {
    local title="${1:-Welcome}"
    local message="${2:-Select an option below}"
    local -n buttons_ref=$3  # Use nameref to access array properly

    local css_file="/tmp/yad_main.css"
    cat > "$css_file" << 'EOF'
* { 
    background-color: #ffffff; 
    color: #1f2937; 
    font-family: "Segoe UI", "Ubuntu", "Helvetica Neue", sans-serif; 
    font-size: 13pt; 
}

window, dialog, decoration { 
    background-color: #ffffff; 
    border-radius: 18px; 
    padding: 20px; 
    box-shadow: 0 12px 40px rgba(0,0,0,0.15); 
}

label, text, textview { 
    background-color: #ffffff; 
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

image { 
    background-color: transparent; 
    margin-bottom: 20px;
    min-width: 80px;
    min-height: 80px;
}
EOF

    # Build --button parameters dynamically
    local yad_buttons=()
    for b in "${buttons_ref[@]}"; do
        yad_buttons+=(--button="$b")
    done

    yad --title="$title" \
        --width=850 --height=600 --center --borders=30 \
        --text="$message" --image="database" --image-on-top \
        --no-escape --css="$css_file" \
        --window-icon="database" \
        "${yad_buttons[@]}"
    
    local ret=$?
    rm -f "$css_file"
    return $ret
}

# ---------------- Options Dialog (Dynamic Menu) ----------------
show_options() {
    local title="${1:-Options}"
    local text="${2:-Select an option}"
    shift 2
    local options=("$@")  # array in format: "Icon" "Label" "Description"

    local css_file="/tmp/yad_options.css"
    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #1f2937; font-family: "Segoe UI", sans-serif; }
window, dialog { background-color: #ffffff; border-radius: 12px; }
treeview { background-color: #f5f5f5; color: #1f2937; border-radius: 10px; font-size: 11pt; padding: 4px; }
treeview header { background-color: #ffffff; color: #d97706; font-weight: bold; }
button { background-image: linear-gradient(to bottom, #f59e0b, #d97706); color: white; border-radius: 10px; padding: 10px 24px; font-weight: bold; border: none; box-shadow: 0 4px 18px rgba(245,158,11,0.35); transition: all 0.2s ease; }
button:hover { background-image: linear-gradient(to bottom, #fcd34d, #fbbf24); box-shadow: 0 6px 22px rgba(245,158,11,0.45); }
button label { color: white; }
EOF

    # Flatten options for yad list
    choice=$(yad --list \
        --title="$title" --width=720 --height=500 --center --text="$text" \
        --column="Icon:IMG" --column="Option" --column="Description" \
        --print-column=2 --hide-column=1 \
        --window-icon="database" --borders=20 --css="$css_file" \
        --button="Back:1" --button="Select:0" \
        "${options[@]}")
    
    local ret=$?
    rm -f "$css_file"
    echo "$choice" | tr -d '|'  # Remove trailing pipe character
    return $ret
}

# ---------------- Results Dialog ----------------
show_results() {
    local title="${1:-Results}"
    local message="${2:-Here are the results}" 
    local width="${3:-500}"
    local height="${4:-300}"

    local css_file="/tmp/yad_results.css"
    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #065f46; font-family: "Segoe UI", sans-serif; font-size: 11pt; }
window, dialog { background-color: #ffffff; border-radius: 12px; padding: 10px; box-shadow: 0 6px 20px rgba(0,0,0,0.1); }
textview, label, text { background-color: #ffffff; color: #065f46; text-align: center; justify-content: center; }
button { background-image: linear-gradient(to bottom, #404040, #1a1a1a); color: white; border-radius: 12px; padding: 10px 24px; font-weight: bold; border: none; box-shadow: 0 4px 18px rgba(0,0,0,0.35); transition: all 0.2s ease; }
button:hover { background-image: linear-gradient(to bottom, #595959, #404040); box-shadow: 0 6px 22px rgba(0,0,0,0.45); }
button label { color: white; }
EOF

    yad --title="$title" \
        --text="$message" \
        --width="$width" --height="$height" --center --borders=20 \
        --button="OK:0" --no-escape --css="$css_file"
    
    rm -f "$css_file"
}

# ---------------- Goodbye Dialog ----------------
show_goodbye_dialog() {
    local css_file="/tmp/dbms_goodbye_style.css"

    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #065f46; font-family: "Segoe UI", sans-serif; }
window, dialog { background-color: #ffffff; border-radius: 12px; }
label, text { text-align: center; justify-content: center; }
button {
    background-image: linear-gradient(to bottom, #404040, #1a1a1a);
    color: white;
    border-radius: 10px;
    padding: 10px 24px;
    font-weight: bold;
    border: none;
    box-shadow: 0 4px 18px rgba(0, 0, 0, 0.35);
    transition: all 0.2s ease;
}
button:hover {
    background-image: linear-gradient(to bottom, #595959, #404040);
    box-shadow: 0 6px 22px rgba(0, 0, 0, 0.45);
}
button label { color: white; }
EOF

    yad --title="👋  Goodbye!" \
        --text="<span font='16' weight='bold' foreground='#059669'>Thank You! 💚</span>

<span font='12' foreground='#047857'>Your data has been safely managed</span>

<span font='10' foreground='#065f46'>See you next time 😊</span>" \
        --button="<span font='11' weight='bold'>✔  OK</span>:0" \
        --width=500 \
        --height=260 \
        --center \
        --timeout=3 \
        --timeout-indicator=bottom \
        --image="$(dirname "$0")/cat.png" \
        --image-on-top \
        --resize \
        --window-icon="database" \
        --borders=20 \
        --no-escape \
        --css="$css_file"

    rm -f "$css_file"
}

# ---------------- Error Dialog ----------------
show_error_dialog() {
    local message="$1"
    
    local css_file="/tmp/yad_error.css"
    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #991b1b; font-family: "Segoe UI", sans-serif; }
window, dialog { background-color: #ffffff; border-radius: 12px; }
label, text { text-align: center; justify-content: center; }
button { background-image: linear-gradient(to bottom, #404040, #1a1a1a); color: white; border-radius: 10px; padding: 10px 24px; font-weight: bold; border: none; }
button:hover { background-image: linear-gradient(to bottom, #595959, #404040); }
button label { color: white; }
EOF

    yad --title="⚠️  Error" \
        --text="<span font='11' foreground='#dc2626'>$message</span>" \
        --button="<span font='10'>OK</span>:0" \
        --width=350 \
        --center \
        --image="dialog-error" \
        --window-icon="dialog-error" \
        --borders=15 \
        --css="$css_file"
    
    rm -f "$css_file"
}

# ---------------- Info Dialog ----------------
show_info_dialog() {
    local title="$1"
    local message="$2"
    
    local css_file="/tmp/yad_info.css"
    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #1e40af; font-family: "Segoe UI", sans-serif; }
window, dialog { background-color: #ffffff; border-radius: 12px; }
label, text { text-align: center; justify-content: center; }
button { background-image: linear-gradient(to bottom, #404040, #1a1a1a); color: white; border-radius: 10px; padding: 10px 24px; font-weight: bold; border: none; }
button:hover { background-image: linear-gradient(to bottom, #595959, #404040); }
button label { color: white; }
EOF

    yad --title="$title" \
        --text="<span font='10'>$message</span>" \
        --button="OK:0" \
        --width=350 \
        --center \
        --image="dialog-information" \
        --borders=15 \
        --css="$css_file"
    
    rm -f "$css_file"
}

# ---------------- Question Dialog ----------------
show_question_dialog() {
    local question="$1"
    
    local css_file="/tmp/yad_question.css"
    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #92400e; font-family: "Segoe UI", sans-serif; }
window, dialog { background-color: #ffffff; border-radius: 12px; }
label, text { text-align: center; justify-content: center; }
button { background-image: linear-gradient(to bottom, #404040, #1a1a1a); color: white; border-radius: 10px; padding: 10px 24px; font-weight: bold; border: none; }
button:hover { background-image: linear-gradient(to bottom, #595959, #404040); }
button label { color: white; }
EOF

    yad --question \
        --title="Question" \
        --text="<span font='10'>$question</span>" \
        --button="Yes:0" \
        --button="No:1" \
        --width=400 \
        --center \
        --image="dialog-question" \
        --borders=15 \
        --css="$css_file"
    
    local ret=$?
    rm -f "$css_file"
    return $ret
}

# ---------------- Entry Dialog ----------------
show_entry_dialog() {
    local title="$1"
    local label="$2"
    local default="$3"
    # WOW
    local css_file="/tmp/yad_entry.css"
    cat > "$css_file" << 'EOF'
* { background-color: #ffffff; color: #1f2937; font-family: "Segoe UI", sans-serif; }
window, dialog { background-color: #ffffff; border-radius: 12px; }
label, text { text-align: center; justify-content: center; }
entry { background-color: #f5f5f5; color: #1f2937; border-radius: 8px; padding: 8px; }
button { background-image: linear-gradient(to bottom, #404040, #1a1a1a); color: white; border-radius: 10px; padding: 10px 24px; font-weight: bold; border: none; }
button:hover { background-image: linear-gradient(to bottom, #595959, #404040); }
button label { color: white; }
EOF

    result=$(yad --entry \
        --title="$title" \
        --text="$label" \
        --entry-text="$default" \
        --width=400 \
        --center \
        --borders=15 \
        --css="$css_file")
    
    local ret=$?
    rm -f "$css_file"
    echo "$result"
    return $ret
}

# Export functions
export -f show_main_dialog
export -f show_options
export -f show_results
export -f show_goodbye_dialog
export -f show_error_dialog
export -f show_info_dialog
export -f show_question_dialog
export -f show_entry_dialog