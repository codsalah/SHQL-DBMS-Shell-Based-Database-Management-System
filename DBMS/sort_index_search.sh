#!/usr/bin/bash

tableName=$1
searchTarget=$2

# if no arguments provided, prompt user
if [ -z "$tableName" ]; then
    read -p "Enter table name: " tableName
    read -p "Enter value to search (optional, press Enter to skip): " searchTarget
fi

# Check if table exists
if [[ ! -f "$tableName" || ! -f "$tableName.meta" ]]; then
    echo "Table or Metadata for '$tableName' does not exist."
    exit 1
fi


# Get Primary Key Index and Type from Metadata
metadata=$(cat "$tableName.meta")
# Split metadata into columns
IFS='|' read -ra columns <<< "$metadata"

# Variable to Store Primary Key Index and Type
pkIndex=0      # 1-based index for sort/cut
pkType=""
currentCol=1

for col in "${columns[@]}"; do
    IFS=':' read -ra parts <<< "$col"
    # parts[0] = name, parts[1] = type, parts[2] = PK (optional)
    
    if [[ "${parts[2]}" == "PK" ]]; then
        pkIndex=$currentCol
        pkType=${parts[1]}
        break
    fi
    ((currentCol++))
done

if [ $pkIndex -eq 0 ]; then
    echo "Error: No Primary Key found in metadata."
    exit 1
fi

# Sort the Data

# Create temporary files
headerFile="${tableName}.header"
bodyFile="${tableName}.body"
sortedBodyFile="${tableName}.sorted_body"

# Extract header (first line)
head -n 1 "$tableName" > "$headerFile"

# Get the header content to use for filtering
headerContent=$(cat "$headerFile")

# Extract body (remaining lines), filtering out any lines that are identical to the header
tail -n +2 "$tableName" | grep -vF "$headerContent" > "$bodyFile"

# Sort based on PK type
if [ "$pkType" == "int" ]; then
    # -n for numeric sort (this will sort the data by the primary key column in the same place)
    sort -t '|' -k"${pkIndex},${pkIndex}n" "$bodyFile" > "$sortedBodyFile"
else
    # default string sort (this will sort the data by the primary key column in the same place)
    sort -t '|' -k"${pkIndex},${pkIndex}" "$bodyFile" > "$sortedBodyFile"
fi

# Reassemble the table (Header + Sorted Body)
cat "$headerFile" "$sortedBodyFile" > "$tableName"

# Clean up temp files
rm "$headerFile" "$bodyFile" "$sortedBodyFile"

# echo "Table '$tableName' sorted by Primary Key."

# Binary Search (if target is provided)

if [ -n "$searchTarget" ]; then
    
    # Function to perform binary search
    binary_search() {
        local target=$1
        local file=$2
        
        # Get total number of data rows
        # We use the file we just sorted ($tableName)
        # Total lines in file
        local totalLines=$(wc -l < "$file")
        # Subtract 1 for header
        local numRows=$((totalLines - 1))
        
        local low=0
        local high=$((numRows - 1))
        local mid
        local lineNum
        local row
        local midVal
        
        while [ $low -le $high ]; do
            mid=$(( (low + high) / 2 ))
            
            # Calculate actual line number in file (Header is line 1, so row 0 is line 2)
            lineNum=$((mid + 2))
            
            # Read the specific line
            row=$(sed -n "${lineNum}p" "$file")
            
            # Extract the PK value from the row
            midVal=$(echo "$row" | cut -d '|' -f "$pkIndex")
            
            if [ "$midVal" == "$target" ]; then
                echo "$row"
                return 0
            fi
            
            if [ "$pkType" == "int" ]; then
                if [ "$midVal" -lt "$target" ]; then
                    low=$((mid + 1))
                else
                    high=$((mid - 1))
                fi
            else
                if [[ "$midVal" < "$target" ]]; then
                    low=$((mid + 1))
                else
                    high=$((mid - 1))
                fi
            fi
        done
        
        echo "Not Found"
        return 1
    }

    binary_search "$searchTarget" "$tableName"
fi