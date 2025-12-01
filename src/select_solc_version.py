import re
import subprocess
import config

def get_solidity_version(file_path):
    with open(file_path, "r") as file:
        for line in file:
            version_match = re.search(r"pragma solidity\s+([^;]+);", line)
            if version_match:
                return version_match.group(1).lstrip('^').strip()
    return None

def switch_solc_version(version):
    if "=" in version:
        match = re.search(r'[><]?=(\d+\.\d+\.\d+)', solidity_version)
        if match:
            version = match.group(1)
    try:
        subprocess.run(['solc-select', 'use', version], check=True)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":

    solidity_version = get_solidity_version(config.SOL_FILE_PATH)

    if solidity_version:
        print(f"Solidity Version: {solidity_version}")
        switch_solc_version(solidity_version)
    else:
        print("Could not find Solidity version in the specified file.")
        print("The default version will be used")
