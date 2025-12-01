from llm.call_gpt import call_chatgpt
# from before.call_deepseek import call_deepseek
import re
import config

class TaintAgent():

    def __init__(self, sinks, constructor_function_name, souce_code):
        self.sinks = sinks
        self.constructor_function_name = constructor_function_name
        self.source_code = souce_code


    def process(self):
        prompt_message = self.generate_prompt()
        # print(prompt_message)
        # print("===============")
        result = ""
        result += call_chatgpt(prompt_message)
        # result += call_deepseek(prompt_message)
        # print(result)
        # pattern = r"--Vulnerability--:\s*\n(.*?)(?=\n\s*\n|$)"
        # matches = re.search(pattern, result, re.DOTALL | re.IGNORECASE)
        # conclusion = ""
        # if matches:
        #     conclusion = matches.group(1).strip()
        # if "no vulnerability" in conclusion.strip().lower():
        #     conclusion = ""
        return result
    
    def generate_prompt(self):
        system_content = """You are a smart contract auditing expert with advanced skills in taint analysis.
        Your task is to analyze whether untrusted inputs can reach any security-sensitive operations, also known as **Sinks**, in the contract.
        Output your reasoning steps. Be precise and factual, avoid hypothetical reasoning.
        Please ensure the output is complete and not truncated.
        """

        construct_str = ""
        if self.constructor_function_name:
            construct_str = f"- Constructor function:{self.constructor_function_name}. Any other function that looks like a constructor or initializer is a wrong constructor."
        else:
            construct_str = "- The contract has no constructor, then treat all functions that look like constructors or initializers as wrong constructors."
        
        if config.No_static:
            construct_str = ""

        taint_rules = """
        1.Only consider actual execution paths and avoid hypothetical branches or assumptions.
        - For functions with internal or private visibility, carefully check whether there is any feasible path that can actually reach them.
        - Functions with public or external visibility can be called by any external account, regardless of how they are invoked internally.
        - Modifiers initializer, onlyInitializing and nonReentrant do not provide access control. They only restrict the number of times a function can be called. Do not treat them as safety.
        2.Cryptographic functions that can be used to indirectly enforce access control:
        - keccak256(bytes memory) returns (bytes32): compute the Keccak-256 hash of the input
        - sha256(bytes memory) returns (bytes32): compute the SHA-256 hash of the input
        - ripemd160(bytes memory) returns (bytes20): compute RIPEMD-160 hash of the input
        - ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) returns (address): recover the address associated with the public key from elliptic curve signature or return zero on error.
        3.Carefully handle withdraw and approve functions. Do not consider normal withdraw or approve functionality as a vulnerability, even if a single path exists
        - function approve(address _spender, uint256 _value) public returns (bool success) {\n        allowed[msg.sender][_spender] = _value;\n        emit Approval(msg.sender, _spender, _value);\n        return true;\n    }
        - function withdraw() public {\n        uint amount = pendingWithdrawals[msg.sender];\n        pendingWithdrawals[msg.sender] = 0;\n        payable(msg.sender).transfer(amount);\n    }
        4.This is intended behavior: any user can purchase the contract’s ownership by paying the required amount in Wei. 
        - Example:uint256 public constant howManyEtherInWeiToBecomeOwner=1000 ether;\n        function changeOwner (address _newowner) payable {\n            if (msg.value>=howManyEtherInWeiToBecomeOwner){\n                owner.transfer(msg.value);\n                owner.transfer(this.balance);\n                owner=_newowner;\n            }\n        }
        - **Do Not** classify such functions as sinks, because the access is explicitly granted by the contract logic.
        5.Time- or state-based conditions (e.g., block number, balances) only limit when a function can be called, not who can call it.
        """

        user_content = f"""Source code: ```{self.source_code}```.
        Identified **Sinks**: {self.sinks}
        Step 1: **Taint Source**: For each sink, determine whether it can be influenced by untrusted input (e.g., msg.sender, tx.origin, function parameters). 
        Note: tx.origin must be treated separately from msg.sender. **Do not** consider msg.value as a taint source.
        {construct_str}
        - Do NOT rely on assumptions, hypothetical branches, or conditional speculation. Avoid using phrases such as "if", "might", "could", or any uncertain language.
        - For selfdestruct, ignore parameters. Check only if a path from msg.sender can reach it.
        - Carefully consider initialization functions. Although they are intended to be called only once, without proper access control they can be invoked by anyone.
        Step 2: **Taint Propagation Path**: Perform taint analysis to determine whether the sink can be tainted by untrusted input. Trace the data flow from untrusted sources to the sink and examine whether any access control mechanisms (such as require statements, conditional branches, or modifiers) effectively restrict this influence.
        {taint_rules}
        Step 3: **Self-Evaluation**: Evaluate your reasoning. If a taint path exists and it affects access control logic, this is an access control vulnerability.
        """

        assistant_content = """
        If an access control vulnerability is detected, your conclusion must strictly follow this format (one line per vulnerability):
        --Vulnerability--:
        {Function:XXX,Taint Path:XXX,Description:XXX}
        {Function:XXX,Taint Path:XXX,Description:XXX}
        If no vulnerabilities are detected, output:
        --Vulnerability--: 
        no vulnerability
        """
        
        msgs = [
            {"role": "system", "content": system_content},
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": assistant_content},
        ]

        return msgs