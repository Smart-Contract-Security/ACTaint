import sys

if __name__ == "__main__":
    file_name = sys.argv[1]
    with open("src/config.py", 'r') as f:
        lines = f.readlines()

    with open("src/config.py", 'w') as f:
        for line in lines:
            if (not line.startswith("SOL_FILE")) and not line.startswith("SOL_FILE_PATH"):
                f.write(line)

        # rewrite LATEST_FILE_NAME 
        f.write(f"SOL_FILE = '{file_name}'\n")
        f.write("SOL_FILE_PATH = DATASET_PATH + SOL_FILE\n")

