#!/bin/bash

TEXT_FILE="624.txt"                   
SOURCE_DIR="./wild/"          
DEST_DIR="./624sol/"            
# ====================================

mkdir -p "$DEST_DIR"


echo "start"
count=0
while IFS= read -r filename || [[ -n "$filename" ]]; do
    
    filepath=$(find "$SOURCE_DIR" -type f -name "$filename" 2>/dev/null | head -n 1)
    
    if [[ -n "$filepath" ]]; then
        cp "$filepath" "$DEST_DIR/"
        count=$((count+1))
        if (( count % 50 == 0 )); then
            echo "copy $count files"
        fi
    else
        echo "can't find $filename"
    fi
done < "$TEXT_FILE"

echo "finish"
