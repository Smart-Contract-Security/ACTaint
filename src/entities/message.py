import json
class Message:
    
    def __init__(self, agnet, content):
        self.agnet = agnet
        self.content = content # must be string

    def to_json(self):
        return json.dumps(self.__dict__, indent=4)
    
    @staticmethod
    def json_to_str(json_data):
        return json.dumps(json_data)
    
    @staticmethod
    def from_json(json_str):
        data = json.loads(json_str)
        return Message(data["agnet"], data["content"])
    
    def get_json_content(self):
        return json.loads(self.content)