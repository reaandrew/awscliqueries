#!/bin/bash

# URL of the AWS Config supported resource types documentation
url="https://docs.aws.amazon.com/config/latest/developerguide/resource-config-reference.html"

# Fetch the HTML content of the page
html_content=$(curl -s "$url")

# Extract the tables containing resource types
tables=$(echo "$html_content" | xmllint --html --xpath '//table' - 2>/dev/null)

# Define a regex pattern for valid AWS resource types
pattern="^AWS::[a-zA-Z0-9]+::[a-zA-Z0-9]+$"

# Initialize an array to store the resource types
resource_types=()

# Parse the tables and extract resource types
echo "$tables" | awk -F'<tr>|</tr>' '{for(i=2;i<=NF;i+=2) print $i}' | while read -r row; do
    resource_type=$(echo "$row" | awk -F'<td>|</td>' '{print $3}' | sed 's/<[^>]*>//g' | xargs)
    if [[ $resource_type =~ $pattern ]]; then
        resource_types+=("$resource_type")
    fi
done

# Print the extracted resource types
for resource in "${resource_types[@]}"; do
    echo "$resource"
done

