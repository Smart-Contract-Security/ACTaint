from slither.slither import Slither
from slither.slithir.operations import Transfer,Assignment,Send,Condition,LowLevelCall
from slither.core.solidity_types.elementary_type import ElementaryType
from slither.slithir.operations.binary import Binary
from slither.slithir.operations.solidity_call import SolidityCall
from slither.slithir.variables.temporary import TemporaryVariable
from slither.slithir.variables.state_variable import StateVariable
from slither.core.cfg.node import NodeType
from build_cv_graph import BuildCVGraph
from entities.cv_node import CVNode
from utils import read_source_code
from llm.sink_agent import SinkAgent
from llm.taint_agent import TaintAgent
from entities.message import Message
import config
import json
import time

# convert to source code
def parse_to_source(path_dict):
    source_dict = {}
    for key, value in path_dict.items():
        if len(value) == 0:
            continue
        
        key_souce = str(key)
        value_source = ""
        # Before converting the value, check first. If there is no function in the value, it means that no function is written to cv, so just set the value to empty.
        if not any(obj.get_type() == 1 for obj in value):
            source_dict[key_souce] = value_source
            continue

        for obj in reversed(value):
            value_source += f"{read_source_code(str(obj.get_node().source_mapping))}"

        source_dict[key_souce] = value_source

    return source_dict

def get_unaffect_functions(nodes):
    functions = []
    for node in nodes:
        if node.get_type() == 1 and node.in_edges == []:
            functions.append(node)
    return functions

if __name__ == "__main__":
    start_time = time.time()
    print("==============Start====================")
    config.total_token = 0

    slither = Slither(config.SOL_FILE_PATH,solc_remaps=config.slither_library)
    # slither = Slither(config.SOL_FILE_PATH)

    summary_report = ""
    for contract in slither.contracts:
        if contract.source_mapping.filename.short != config.SOL_FILE_PATH:
            continue

        # filter
        if contract.is_interface or contract.is_abstract or contract.is_library:
            continue
        has_impl = any(f.is_implemented for f in contract.functions_declared)
        if not has_impl:
            continue

        # skip the contract which all pure or view
        all_pure_or_view = all((f.pure or f.view) for f in contract.functions_declared if f.is_implemented )
        # print(f"contract:{contract.name},pure:{all_pure_or_view}")
        if all_pure_or_view:
            continue

        focus_rules = ""
        vulnerability_report = ""
        tx_report = ""
        cv_graph = BuildCVGraph(contract)
        # cv_graph.display_graph()
        
        for variable_node, function_set in cv_graph.functions_uneffect_critical_variables.items():
            if len(function_set) == 0:
                continue
            for function_node in function_set:
                focus_rules += f"{{Function:{str(function_node)}, Visibility:{function_node.node.visibility}, Explanation:Writes to variable {variable_node} without any access control.}}\n"

        # selfdestruct
        for function, variables in cv_graph.selfdestruct.items():
            
            s = ""
            if len(variables) != 0:
                s += "Affected by variable:"
                for variable in variables:
                    s += str(variable)
                s += ", "

            focus_rules += f"{{Function:{str(function)}, Visibility:{function.visibility}, {s}Explanation:Uses selfdestruct instruction.}}\n"

        # Incorrect usage of tx.origin is directly classified as AC.
        for function in cv_graph.get_tx():
            tx_report += f"{{Function: {str(function)}, Explanation: Uses tx.origin as condition.}}\n"

        for function in cv_graph.get_lowcall():
            focus_rules += f"{{Function:{str(function)}, Visibility:{function.visibility}, Explanation:Uses low level call.}}\n"

        for function in cv_graph.get_assembly():
            focus_rules += f"{{Function:{str(function)}, Visibility:{function.visibility}, Explanation:Uses assembly.}}\n"

        for function in cv_graph.get_transfer():
            focus_rules += f"{{Function:{str(function)}, Visibility:{function.visibility}, Explanation:Transfers Ether or Token.}}\n"

        
        constructor_function_name = ""
        if contract.constructor is not None:
            constructor_function_name = contract.constructor.full_name
            # read_source_code(str(constructor.source_mapping))
            # print(constructor)
            # print(f"  Source mapping:{constructor.source_mapping}")
            # print(f"  Constructor found at line {constructor.source_mapping.lines}")
            # print(constructor.full_name)
            # print(constructor.source_mapping._get_lines_str())
            # print(read_source_code(str(constructor.source_mapping)))

        # read_source_code(str(contract.source_mapping))
        
        
        # continue
        
        if focus_rules == "" and tx_report == "":
            continue
        print("rules:")
        print(focus_rules)
        print(f"=============Contract: {contract.name}")
        
        print("Sink:")

        sink_agent = SinkAgent(focus_rules, constructor_function_name, read_source_code(str(contract.source_mapping)))
        sinks = sink_agent.process()
        # print(sinks)

        if config.No_taint:
            # For No_taint, sinks are vulnerabilities.
            vulnerability_report += sinks + "\n"
        else:
            # sinks exist, taint
            if "no sinks" not in sinks.strip().lower():
                taint_agent = TaintAgent(sinks, constructor_function_name, read_source_code(str(contract.source_mapping)))
                vulnerability_report += taint_agent.process() + "\n"
        
        # if vulnerability_report != "":
        #     summary_report = f"contract:{contract.name}\n" + vulnerability_report
    
        print("Report:")
        if tx_report != "":
            tx_report = "--Tx.origin Vulnerability--:\n" + tx_report
        print(vulnerability_report + tx_report)
    
    end_time = time.time()
    print("==============End======================")
    print(f"total time: {end_time - start_time}")
    print(f"total token: {config.total_token}")
    # if summary_report != "":
    #     print("Detect access control vulnerabilities:")
    #     print(summary_report)
    # else:
    #     print("No access control vulnerabilities detected.")