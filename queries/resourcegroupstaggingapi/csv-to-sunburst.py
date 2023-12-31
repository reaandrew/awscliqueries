import json
import sys

# Initialize the data structure
data = {
    "name": "flare",
    "children": []
}

# A dictionary to keep track of services and their resources
services = {}

# Read from stdin
for line in sys.stdin:
    service, resource, count = line.strip().split(',')
    if service not in services:
        services[service] = {}
    services[service][resource] = int(count)

# Convert the services dictionary to the required JSON structure
for service, resources in services.items():
    children = [{"name": resource, "value": count} for resource, count in resources.items()]
    data["children"].append({"name": service, "children": children})

# Print or save the JSON output
print(json.dumps(data, indent=4))
