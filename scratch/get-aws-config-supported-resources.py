import requests
from bs4 import BeautifulSoup
import re

# URL of the AWS Config supported resource types documentation
url = "https://docs.aws.amazon.com/config/latest/developerguide/resource-config-reference.html"

# Send a GET request to fetch the HTML content of the page
response = requests.get(url)
soup = BeautifulSoup(response.content, "html.parser")

# Extracting the tables containing resource types
tables = soup.find_all("table")

resource_types = []

# Define the regex pattern for valid AWS resource types
pattern = re.compile(r"^AWS::[a-zA-Z0-9]+::[a-zA-Z0-9]+$")

for table in tables:
    # Assuming the first row is the header, so we skip it
    rows = table.find_all("tr")[1:]
    for row in rows:
        columns = row.find_all("td")
        if len(columns) > 1:
            resource_type = columns[1].text.strip()
            if pattern.match(resource_type):
                resource_types.append(resource_type)

# Print the extracted resource types
for resource in resource_types:
    print(resource)

