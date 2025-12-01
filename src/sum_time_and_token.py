import re
import csv

input_file = "624.txt"
output_file = "contracts_time_token.csv"

with open(input_file, "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(
    r"The \d+ Line:\s*(\S+\.sol).*?={10,}End={10,}\s*total time:\s*([0-9.]+)\s*total token:\s*(\d+)",
    re.DOTALL
)

matches = pattern.findall(content)

results = []
for match in matches:
    contract_name, total_time, total_token = match
    results.append([contract_name, float(total_time), int(total_token)])

with open(output_file, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Contract", "Total Time", "Total Token"])
    writer.writerows(results)

print(f"Done! {len(results)} contracts processed. Results saved to '{output_file}'")
