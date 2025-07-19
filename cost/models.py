class ServiceModel:
    def __init__(self, name):
        self.name = name
        self.version = "1.0-test"

    def get_info(self):
        return f"Model Name: {self.name}, Version: {self.version}"
