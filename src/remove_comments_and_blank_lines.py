import re
import argparse
import os


def remove_comments_and_empty_lines(sol_code):
    string_pattern = r'(".*?(?<!\\)"|\'.*?(?<!\\)\')'
    strings = re.findall(string_pattern, sol_code)
    string_placeholders = {f"__STR{i}__": s for i, s in enumerate(strings)}
    for key, val in string_placeholders.items():
        sol_code = sol_code.replace(val, key)

    without_comments = re.sub(r'\/\/.*|\/\*[\s\S]*?\*\/', '', sol_code)

    for key, val in string_placeholders.items():
        without_comments = without_comments.replace(key, val)

    cleaned_code = '\n'.join([line for line in without_comments.splitlines() if line.strip()])

    return cleaned_code


def process_files(input_dir, output_dir):
    for root, dirs, files in os.walk(input_dir):
        for file in files:
            if file.endswith(".sol"):
                input_file_path = os.path.join(root, file)

                relative_path = os.path.relpath(input_file_path, input_dir)
                output_file_path = os.path.join(output_dir, relative_path)

                output_file_dir = os.path.dirname(output_file_path)
                if not os.path.exists(output_file_dir):
                    os.makedirs(output_file_dir)

                with open(input_file_path, 'r', encoding='utf-8') as file:
                    solidity_code = file.read()

                cleaned_solidity_code = remove_comments_and_empty_lines(solidity_code)

                with open(output_file_path, 'w', encoding='utf-8') as cleaned_file:
                    cleaned_file.write(cleaned_solidity_code)

                print(f"Finsh: {input_file_path} -> {output_file_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Remove comments and empty lines from all .sol files in a directory.')
    parser.add_argument('input_dir', type=str, help='Path to the input directory containing .sol files.')
    parser.add_argument('output_dir', type=str, help='Path to the output directory to save cleaned .sol files.')

    args = parser.parse_args()

    if not os.path.isdir(args.input_dir):
        print(f"{args.input_dir} does not exist!")
    else:
        process_files(args.input_dir, args.output_dir)
