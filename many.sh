#!/bin/bash

# Input file
FILE_LIST="sol_name/nocompile.txt"

# Define a counter
count=0

# read each line from FILE_LIST
while IFS= read -r line; do
    # count
    count=$((count + 1))

    echo "The $count Line: $line"
	
    python src/run_files.py "$line"
    python src/select_solc_version.py
    python src/analyze_smart_contract.py
    # Enable this when using no-static
    # python src/analyze_smart_contract-no-static.py

done < "$FILE_LIST"