import os
import json
import shutil

# from entities.contract_filter_state_variables import ContractFilterStateVariables
from slither.core.declarations.modifier import Modifier

def read_sol(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()
            return content
    except FileNotFoundError:
        print("Error: The file was not found.")
    except IOError:
        print("Error: There was an issue reading the file.")

def create_dir(log_file):
    if os.path.exists(log_file):
        shutil.rmtree(log_file)
    os.makedirs(log_file)

def read_source_code(source_mapping):
    file_path, lines_range = source_mapping.split('#')
    if '-' in lines_range:
        start_line, end_line = map(int, lines_range.split('-'))
    else:
        start_line = end_line = int(lines_range)
    with open(file_path, 'r') as file:
        lines = file.readlines()
        return ''.join(lines[start_line - 1:end_line])

def find_modifier(function_write):
    modifiers = []
    all_calls = function_write.all_internal_calls()
    for call in all_calls:
        if isinstance(call, Modifier):
            modifiers.append(call)
    return modifiers


def append_to_file(file_path, content):
    with open(file_path, 'a') as file:
        file.write(content + '\n')


def load_rag_json(file_name,knowledge_id):
    with open(f"../RAG/{file_name}", "r") as f:
        data = json.load(f)
    result = ""
    for item in data[knowledge_id]:
        result += str(item)

    return result

def write_result(file_name, content):
    try:
        with open(file_name, 'w') as file:
            file.write(content)
    except Exception as e:
        print(f"error: {e}")

def read_result(file_path):
    content = ""
    try:
        with open(file_path, 'r') as file:
            content = file.read()
    except FileNotFoundError:
        content = ""

    return content