from utils import read_sol
from llm.sink_agent import SinkAgent
from llm.taint_agent import TaintAgent
from entities.message import Message
import config
import json
import time

if __name__ == "__main__":
    start_time = time.time()

    vulnerability_report = ""
        
    print("Sink:")
    
    sink_agent = SinkAgent("", "", read_sol(str(config.SOL_FILE_PATH)))
    sinks = sink_agent.process()
    
    if "no sinks" not in sinks.strip().lower():
        taint_agent = TaintAgent(sinks, "", read_sol(str(config.SOL_FILE_PATH)))
        vulnerability_report += taint_agent.process() + "\n"
    
    print("Report:")
    print(vulnerability_report)
    
    end_time = time.time()
    print("==============Result======================")
    print(f"total time: {end_time - start_time}")
    print(f"total token: {config.total_token}")