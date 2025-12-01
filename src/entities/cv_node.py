from slither.core.declarations.function import FunctionType
class CVNode:
    # node: function or variable 
    # 0 = constructor, 1 = regular function, 2 = variable, 3 = modifier
    def __init__(self, node, type):
        self.node = node 
        self.type = type
        # dependency relationships
        self.out_edges = []  # arrow points from this node
        self.in_edges  = []  # arrow points to this node

    def get_node(self):
        return self.node

    def get_type(self):
        return self.type

    def __eq__(self, other):
        if isinstance(other, CVNode):
            return self.node == other.node and self.type == other.type
        return False

    def __hash__(self):
        return hash((self.node, self.type))

    def __str__(self):
        return str(self.node)
    
    def get_dependency_graph(self):
        visited = []
        result = []
        self._dfs_in(visited, result)
        # self._dfs_out(visited, result)
        return result

    def _dfs_in(self, visited, result):
        for in_node in self.in_edges:
            if in_node.get_type() == 3: # Do not add variables
                continue
            if in_node not in visited:
                visited.append(in_node)
                result.append(in_node)
                in_node._dfs_in(visited, result)
        
    def _dfs_out(self, visited, result):
        for in_node in self.out_edges:
            if in_node not in visited:
                visited.append(in_node)
                result.append(in_node)
                in_node._dfs_in(visited, result)
                
    def get_all_in_edges(self):
        visited = []
        all_in_edges = []
        self._dfs_before(visited, all_in_edges)
        return all_in_edges

    def _dfs_before(self, visited, all_in_edges):
        for in_node in self.in_edges:

            if in_node.get_type() == 1:
                # Skip variables initialized during declaration
                if in_node.get_node()._function_type == FunctionType.CONSTRUCTOR_VARIABLES or in_node.get_node()._function_type == FunctionType.CONSTRUCTOR_CONSTANT_VARIABLES:
                    continue
            # Skip the constructor
            elif in_node.get_type() == 0:
                continue

            if in_node not in visited:
                visited.append(in_node)
                all_in_edges.append(in_node)
                # Continue recursion
                in_node._dfs(visited, all_in_edges)