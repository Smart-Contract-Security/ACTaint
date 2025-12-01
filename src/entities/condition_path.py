class ConditionPath:

    def __init__(self, left, operation, right):
        self.left = left
        self.operation = operation
        self.right = right

    def get_left(self):
        return self.left
    
    def get_right(self):
        return self.right
    
    def __str__(self):
        return str(self.left) + self.operation + str(self.right)