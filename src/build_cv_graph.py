from entities.cv_node import CVNode
from slither.slithir.operations import Assignment
from slither.core.solidity_types.elementary_type import ElementaryType
from slither.slithir.operations import Binary,BinaryType,InternalCall,SolidityCall
from slither.core.declarations.function import Function,FunctionType
from slither.core.cfg.node import Node,NodeType
from slither.slithir.variables.state_variable import StateVariable
from slither.core.declarations import SolidityVariable
from slither.core.expressions import CallExpression
from slither.core.declarations.solidity_variables import SolidityFunction
class BuildCVGraph:

    def __init__(self, contract): 
        self.contract = contract
        self.all_nodes = set()
        self.critical_variables = set()
        self._extract_critical_variables()

        # build graph
        self._build_graph()
        self.functions_uneffect_critical_variables = {}
        self.find_unaffect_functions()
        # # critical  instructions
        self.selfdestruct = {}
        self.tx = set()
        self.assembly = set()
        self.lowcall = set()
        self.transfer = set()
        self.check_instrcutions()


    def read_variable_in_binary(self, function, varibale):
        for function_node in function.nodes:
            if function_node: 
                for ir in function_node.irs:
                    # Only handle binary comparisons.
                    if isinstance(ir, Binary) and BinaryType.return_bool(ir.type):
                        if ir.variable_left == varibale or ir.variable_right == varibale:
                            return True
        return False        

    def _extract_critical_variables(self):
        if len(self.contract.state_variables) == 0:
                return None
        else:
            for state_variable in self.contract.state_variables:
                is_sv = False
                # Iterate through all functions and modifiers (including inherited and declared); return True if the condition reads it.
                for function in self.contract.functions_and_modifiers:
                    if function.is_reading_in_conditional_node(state_variable) or function.is_reading_in_require_or_assert(state_variable) or self.read_variable_in_binary(function, state_variable):
                        is_sv = True
                        break
                # If True, add it.
                if is_sv:
                    self.critical_variables.add(state_variable)

    def _build_graph(self):
        for cv in self.critical_variables:
            cvn = CVNode(cv,2) # 2 is variable
            self.all_nodes.add(cvn)
        for function in self.contract.functions_declared:
            # skip constructor
            if function.is_constructor or function._function_type == FunctionType.CONSTRUCTOR_VARIABLES or function._function_type == FunctionType.CONSTRUCTOR_CONSTANT_VARIABLES:
                continue
            cvn = CVNode(function,1) # 1 is function
            self.all_nodes.add(cvn)
        # no modifier
         
        for node in self.all_nodes:
            # function
            if node.type == 1: 
                function = node.node
                
                for sv in function.all_state_variables_written():
                    for cv in self.all_nodes:
                        if cv.node == sv and cv.type ==2:
                            self._add_edges(node, cv)
                            break

                # print(f"function:{function}")
                for sv in function.all_state_variables_read():
                    modifier_sv_set = set()
                    for modifier in function.modifiers:
                        for modifier_sv in modifier.all_state_variables_read():
                            modifier_sv_set.add(modifier_sv)
                    if function.is_reading_in_conditional_node(sv) or function.is_reading_in_require_or_assert(sv) or self.read_variable_in_binary(function, sv) or sv in modifier_sv_set:
                        for cv in self.all_nodes:
                            if cv.node == sv and cv.type ==2:
                                self._add_edges(cv, node)
                                break

    def display_graph(self):
        for node in self.all_nodes:
            print(f"===node:{node}===")
            print("in edge:")
            for ine in node.in_edges:
                print(ine)
            print("out edge:")
            for oute in node.out_edges:
                print(oute)

    def find_unaffect_functions(self):
        for node in self.all_nodes:
            # variable
            if node.type == 2: 
                # print(f"node:{node}")
                unaffect_function = set()
                for in_node in node.in_edges:
                    
                    # no function, skip
                    if in_node.type != 1:
                        continue

                    if in_node.in_edges != []:
                        continue
                    
                    unaffect_function.add(in_node)

                self.functions_uneffect_critical_variables[node] = unaffect_function


    def _add_edges(self,from_node, to_node):
        from_node.out_edges.append(to_node)
        to_node.in_edges.append(from_node)
        
    def get_critical_variables(self):
        return self.critical_variables
    
    def check_instrcutions(self):
        # check function
        if self.contract.functions_declared is not None:
            # tx.origin in modifier
            for modifier in self.contract.modifiers:
                for var in modifier.all_conditional_solidity_variables_read():
                    if str(var) == "tx.origin":
                        self.tx.add(modifier)

            for function in self.contract.functions_declared:
                # skip construct function.
                if function.is_constructor or function._function_type == FunctionType.CONSTRUCTOR_VARIABLES or function._function_type == FunctionType.CONSTRUCTOR_CONSTANT_VARIABLES:
                    continue

                for var in function.all_conditional_solidity_variables_read():
                    if str(var) == "tx.origin":
                        self.tx.add(function)

                state_vars = set()
                is_selfdestruct = False
                # print(function)
                for node in function.nodes:
                    for ir in node.irs:
                        # print(ir)
                        if isinstance(ir, SolidityCall):
                            target = ir.function
                            if isinstance(target, SolidityFunction) and ("selfdestruct" in target.name or "suicide(address)" in target.name):
                                is_selfdestruct = True
                                condition_node = None
                                for father in node.fathers:
                                    if father.type == NodeType.IF:
                                        condition_node = father
                                        break
                                    # require and assert
                                    if father.type == NodeType.EXPRESSION:
                                        if "require(bool)" in str(father) or "assert(bool)" in str(father):
                                            condition_node = father
                                            break
                                if condition_node:
                                    for var in condition_node.variables_read:
                                        if isinstance(var,StateVariable):
                                            for node in self.all_nodes:
                                                if node.type == 2:
                                                    if node.node == var:
                                                        state_vars.add(node)
                if is_selfdestruct:
                    affect_variables = set()
                    for s in state_vars:
                        affect_variable = self.dfs_for_variable(s)
                        if affect_variable:
                            affect_variables.add(affect_variable)
                    
                    # modifiers
                    for modifier in function.modifiers:
                        for sv in modifier.all_state_variables_read():
                            affect_variables.add(sv)
                    self.selfdestruct[function] = affect_variables

                # in external_calls_as_expressions
                external_calls = [str(c) for c in function.external_calls_as_expressions]
                # low-level call
                if any(substring in call for substring in ["delegatecall", ".call(", "staticcall"] for call in external_calls):
                    self.lowcall.add(function)

                # transfer operations
                if any("transfer(" in call for call in external_calls) or any("send(" in call for call in external_calls):
                    self.transfer.add(function)

                # assembly
                if function.contains_assembly:
                    self.assembly.add(function)
    
    def dfs_for_variable(self, now_node, visited=None):
        if not isinstance(now_node, CVNode):
            return None
        
        if visited is None:
            visited = set()
        if now_node in visited:
            return None
        
        visited.add(now_node)
        if now_node.in_edges == []:
            return now_node
        

        for in_node in now_node.in_edges:
            source = self.dfs_for_variable(in_node,visited)
        if source:
            return source
        
        return None
    
    def analyze_tx(self, function):
        if function is None:
            return
        for modifier in function.modifiers:
            for modifier_node in modifier.nodes: 
                if modifier_node:
                    for ir in modifier_node.irs:
                        if isinstance(ir, Binary):
                            if (str(ir.variable_left) == "tx.origin" and str(ir.variable_right) != "msg.sender") or (str(ir.variable_right) == "tx.origin" and str(ir.variable_left) != "msg.sender"):
                                self.tx.add(function)
                                return
                            
        for function_node in function.nodes:
            if function_node:
                for ir in function_node.irs:
                    if isinstance(ir, Binary):
                        if (str(ir.variable_left) == "tx.origin" and str(ir.variable_right) != "msg.sender") or (str(ir.variable_right) == "tx.origin" and str(ir.variable_left) != "msg.sender"):
                            self.tx.add(function)
                            return


    def get_tx(self):
        return self.tx
    
    def get_selfdestruct(self):
        return self.selfdestruct
    
    def get_assembly(self):
        return self.assembly
    
    def get_lowcall(self):
        return self.lowcall
    
    def get_transfer(self):
        return self.transfer