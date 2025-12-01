from llm.call_gpt import call_chatgpt
# from before.call_deepseek import call_deepseek
import re
import config

class SinkAgent():

    def __init__(self, static_rules, constructor_function_name, souce_code):
        self.static_rules = static_rules
        self.constructor_function_name = constructor_function_name
        self.source_code = souce_code

    def process(self):
        prompt_message = self.generate_prompt()
        # print(prompt_message)
        result = ""
        result += call_chatgpt(prompt_message)
        # result += call_deepseek(prompt_message)
        print(result)  
        pattern = r"--Sink--:\s*\n(.*?)(?=\n\s*\n|$)"
        matches = re.search(pattern, result, re.DOTALL)
        conclusion = ""
        if matches:
            conclusion = matches.group(1).strip()
            # print(conclusion)
        return conclusion
    
    def generate_prompt(self):

        system_content = """You are a smart contract auditing expert skilled in taint analysis.
        You task is to identify all **Sink** operations.
        A **Sink** is a security-sensitive operation that may cause access control vulnerabilities.
        Output your reasoning steps. Be precise and factual, avoid hypothetical reasoning.
        Please ensure the output is complete and not truncated.
        """

        construct_str = ""
        if self.constructor_function_name:
            construct_str = f"- Constructor function:{self.constructor_function_name}. Only this function is the constructor. Do not consider Solidity version or other conditions and Simply accept it as the constructor. Any other function that looks like a constructor or initializer is a wrong constructor and must be treated as a sink."
        else:
            construct_str = "- The contract has no constructor, then treat all functions that look like constructors or initializers as wrong constructors and mark them as sinks."
        
        if config.No_static:
            construct_str = ""
            self.static_rules = ""   
        
        other_rules = """
        To help you better identify sinks, here are some examples for you to learn from.
        1.Carefully evaluate standard ERC-20 operations such as approve, transfer, transferFrom, _transfer, balance/allowance updates, and properly guarded minting/burning before labeling them as sinks.
        - Standard approve function, sets allowance of _spender: 
            function approve(address _spender, uint256 _value) public returns (bool success) {\n        allowed[msg.sender][_spender] = _value;\n        emit Approval(msg.sender, _spender, _value);\n        return true;\n    }
        - Standard transfer function, moves tokens from sender (msg.sender) to recipient (to): 
            function transfer(address _to, uint256 _value) public returns (bool success) {\n        require(balances[msg.sender] >= _value);\n        balances[msg.sender] -= _value;\n        balances[_to] += _value;\n        emit Transfer(msg.sender, _to, _value);\n        return true;\n    }
        - Standard transferFrom function, moves tokens from _from to _to using allowance: 
            function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {\n        uint256 allowance = allowed[_from][msg.sender];\n        require(balances[_from] >= _value && allowance >= _value);\n        balances[_to] += _value;\n        balances[_from] -= _value;\n        if (allowance < MAX_UINT256) {\n            allowed[_from][msg.sender] -= _value;\n        }\n        emit Transfer(_from, _to, _value); \n        return true;\n    }
        - Standard mint function, mint new tokens:
            function mint(uint256 _value) public returns (bool success) {\n               balanceOf[msg.sender] += _value;\n               totalSupply += _value;\n               emit Mint(msg.sender, _value);\n               return true;\n           }
        - Standard burn function:
            function burn(uint256 _value) public returns (bool success) {\n                require(balances[msg.sender] >= _value);\n                balances[msg.sender] -= _value;\n                totalSupply -= _value;\n                emit Burn(msg.sender, _value);\n                return true;\n            }
        - **Notice**:  
            Check whether `from` equals `msg.sender` or has approval, and whether `to`/`recipient` equals `msg.sender`.  
            Modifying only the caller’s (`msg.sender`) own state/assets is acceptable, but modifying others’ without authorization is a sink.
        2. Cryptographic functions that can be used to indirectly enforce access control:
        - keccak256(bytes memory) returns (bytes32): compute the Keccak-256 hash of the input
        - sha256(bytes memory) returns (bytes32): compute the SHA-256 hash of the input
        - ripemd160(bytes memory) returns (bytes20): compute RIPEMD-160 hash of the input
        - ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) returns (address): recover the address associated with the public key from elliptic curve signature or return zero on error.
        3. This is intended behavior: any user can purchase the contract’s ownership by paying the required amount in Wei. 
        - Example:uint256 public constant howManyEtherInWeiToBecomeOwner=1000 ether;\n        function changeOwner (address _newowner) payable {\n            if (msg.value>=howManyEtherInWeiToBecomeOwner){\n                owner.transfer(msg.value);\n                owner.transfer(this.balance);\n                owner=_newowner;\n            }\n        }
        - **Do Not** classify such functions as sinks, because the access is explicitly granted by the contract logic.
        4. Some modifiers or require conditions **do not provide access control**.  
        - If a function is only protected by them, it cannot be excluded from sink consideration. Do not treat them as safety checks.  
        - Modifiers initializer, onlyInitializing, onlyNotInitializing only restrict the number of times a function can be called, **but do not restrict who can call it**.  
        - Modifier nonReentrant only prevents reentrancy, it does not enforce access control.
        """
    
        user_content = f"""Source code: ```{self.source_code}```.
        Step 1: **Reference**: Here is a static analysis result: {self.static_rules}.
        - Use this as a reference, but rely on the actual context. Be careful before marking functions not listed as sinks.
        - For selfdestruct instructions, if they are affected by other variables, this usually indicates some level of protection. Carefully consider before identifying them as sinks.
        Step 2: **Identify Sink**: Identify all **Sink** operations in the source code.
        {construct_str}
        - Do NOT rely on assumptions, hypothetical branches, or conditional speculation. Avoid using phrases such as "if", "might", "could", or any uncertain language.
        - Treat init functions as potential sinks. Although they are intended to be called only once, without proper access control they can be invoked by anyone.
        {other_rules}
        Step 3: **Self-Evaluate and Explain**: For each **Sink**, self-evaluate and then provide a formal explanation for it.
        """     
        
        assistant_content = """
        Finally, if any sinks are identified, your conclusion must strictly follow this format (one line per sink):
        --Sink--:
        {Function: XXX, Sink: XXX, Visibility:XXX, Explanation: XXX}
        {Function: XXX, Sink: XXX, Visibility:XXX, Explanation: XXX}
        If no valid sinks are found, output:
        --Sink--: 
        no sinks
        """

        msgs = [
            {"role": "system", "content": system_content},
            {"role": "user", "content": user_content},
            {"role": "assistant", "content": assistant_content},
        ]

        return msgs
