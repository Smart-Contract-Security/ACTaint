# ACTaint

**Paper Title:** ACTAINT: Agent-Based Taint Analysis for Access Control Vulnerabilities in Smart Contracts

## Quick Start

Python 3.12.4

```pip install -r requirements.txt```

vim ```config.py```  

write *gpt_url, gpt_key*

```sh start.sh```

## Organization:

- `datasets`: All datasets
    - `clean_datasets`: Remove comments and empty lines, **used in our experiment**.
    - `raw_datasets`: raw, used as a reference

- `discussion`: The results used in our section Discussion.

- `experiment`: All experiment results

- `logs`: All logs

- `sol_name`: Name of the Solidity file

- `src`: source code     
    - `entities/`: Contains data and definitions.
    - `LLM/`: AI agents.
    - `config.py`: Configuration file **(Important)**

- `many.sh`: Script for batch execution (needs to be edited before use).

- `start.sh`: Script to start the program.


## Other Logs:
    For the logs of GPTLens and AChecker, please visit [Other Logs](https://github.com/Smart-Contract-Security/ACTaint_Other)