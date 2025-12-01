class ACTreeNode:
    
    # This stores state variables (the root node only has the string "root")
    def __init__(self, node):
        self.node = node
        self.initial_value = ""
        self.children = []

    def add_child(self, child):
        self.children.append(child)
    
    def get_child(self):
        return self.children
    
    def get_initial_value(self):
        return self.initial_value

    def remove(self, node_to_remove):
        for child in self.children:
            if child == node_to_remove:
                self.children.remove(child)
            else:
                child.remove(node_to_remove)

    def get_node(self):
        return self.node
    
    def set_initial_value(self, target_node, value):
        if self.node == target_node:
            self.initial_value = value
            return True

        for child in self.children:
            if child.set_initial_value(target_node,value):
                return True
            
        return False

    def __repr__(self, level=0):
        res = "\t" * level + f"{self.node} \n"
        for child in self.children:
            res += child.__repr__(level + 1)
        return res
    
    def __eq__(self, other):
        if isinstance(other, ACTreeNode):
            return self.node == other.node 
        return False
    
    def __hash__(self):
        return hash(self.node)

    # def __str__(self):
    #     return str(self.node)
