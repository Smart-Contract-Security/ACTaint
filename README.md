# ACTaint

**Paper Title:** ACTAINT: Agent-Based Taint Analysis for Access Control Vulnerabilities in Smart Contracts

## Quick Start

Python 3.12.4

```pip install -r requirements.txt```

vim ```config.py```  

write *gpt_url, gpt_key*

```sh start.sh```

### Directory `Src`:

- `datasets`: All datasets
    - `clean_datasets`: Remove comments and empty lines
    - `raw_datasets`: raw

- `results`: All results

- `sol_name`: Name of the Solidity file

- `src`: source code     
    - `entities/`: Contains data and definitions.
    - `LLM/`: AI agents.
    - `config.py`: Configuration file **(Important)**
- `CVE/`: Dataset folder for CVE entries.

- `many.sh`: Script for batch execution (needs to be edited before use).

- `start.sh`: Script to start the program (needs to be edited before use).
