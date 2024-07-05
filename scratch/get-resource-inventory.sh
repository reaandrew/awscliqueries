#!/bin/bash

# Function to get all resource IDs for a given resource type
get_resource_ids() {
    local resource_type=$1
    aws configservice list-discovered-resources --resource-type "$resource_type" --query 'resourceIdentifiers[].resourceId' --output text
}

# Function to get configuration for multiple resource IDs using batch-get-resource-config
get_batch_config() {
    local resource_type=$1
    shift
    local resource_ids=("$@")

    # Filter out any empty or invalid resource IDs
    valid_resource_ids=()
    for id in "${resource_ids[@]}"; do
        if [[ -n "$id" ]]; then
            valid_resource_ids+=("$id")
        fi
    done

    # Check if valid_resource_ids is empty
    if [ ${#valid_resource_ids[@]} -eq 0 ]; then
        echo "No valid resources found for $resource_type" >&2
        return
    fi

    # Create the JSON payload for batch-get-resource-config
    resource_keys=$(printf '%s\n' "${valid_resource_ids[@]}" | jq -R --arg type "$resource_type" '[inputs | {"resourceType": $type, "resourceId": .}]')

    if [ "$resource_keys" == "[]" ]; then
        echo "No valid resources found for $resource_type after filtering." >&2
        return
    fi

    echo "Fetching config for $resource_type with resource keys: $resource_keys"

    aws configservice batch-get-resource-config --resource-keys "$resource_keys" --output json || {
        echo "Error fetching config for $resource_type with resource keys: $resource_keys" >&2
    }
}


# Main function to process each resource type
process_resource_type() {
    local resource_type=$1
    resource_ids=$(get_resource_ids "$resource_type")

    # Convert resource_ids string to array
    IFS=$'\t' read -r -a resource_ids_array <<< "$resource_ids"

    # Check if resource_ids_array is empty
    if [ ${#resource_ids_array[@]} -eq 0 ]; then
        echo "No resources found for $resource_type" >&2
        return
    fi

    echo "Processing $resource_type with resource IDs: ${resource_ids_array[*]}"  >&2

    # Batch requests in groups of 20
    batch_size=20
    for ((i=0; i<${#resource_ids_array[@]}; i+=batch_size)); do
        batch=("${resource_ids_array[@]:i:batch_size}")
        get_batch_config "$resource_type" "${batch[@]}"
    done
}

# Get all valid resource types
resource_types=$(curl -s https://docs.aws.amazon.com/config/latest/developerguide/resource-config-reference.html | grep -Po "([\w]+::){2}[\w]+")

# Export functions and variables for parallel execution
export -f get_resource_ids
export -f get_batch_config
export -f process_resource_type

# Run in parallel
echo "$resource_types" | tr ' ' '\n' | parallel -j 10 process_resource_type

echo "Processing completed."  >&2
