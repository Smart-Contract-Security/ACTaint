class ACFGNode:
    # Input: a string, which can be a function name or a variable name
    # 0 = constructor, 1 = other function, 2 = modifier, 3 = state variable
    def __init__(self, name, type):
        self.name = name # Name as a node
        self.type = type
        # dependency relationships
        self.depend_edges = []  # Dependend edge: B depends on 'owner' because A uses require(owner)
        self.write_edges  = []  # Called write edge (Influence edge): A writes to 'owner'

    def get_name(self):
        return self.name

    def get_type(self):
        return self.type

    def __eq__(self, other):
        if isinstance(other, ACFGNode):
            return self.name == other.name
        return False

    def __hash__(self):
        return hash(self.name)

    def __str__(self):
        return str(self.name)