#!/bin/bash

start_time="$(date -u -d '1 month ago' '+%Y-%m-%dT%H:%M:%SZ')"
end_time="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "Function, Avg Duration, Sum Invocations, Sum Errors, Avg Cold Start Duration, Max Memory, Max Concurrent Executions, Sum Throttles"

# Mapping of metric names to their required statistics operation
declare -A metric_statistics_map=(
    [Duration]="Average"
    [Invocations]="Sum"
    [Errors]="Sum"
    [InitDuration]="Average"
    [MaxMemoryUsed]="Maximum"
    [ConcurrentExecutions]="Maximum"
    [Throttles]="Sum"
)

aws lambda list-functions | jq -r '.Functions[].FunctionName' | while IFS= read -r fn; do
    metrics_output=""

    # Loop through each metric and retrieve the corresponding statistic
    for metric in "${!metric_statistics_map[@]}"; do
        statistic=${metric_statistics_map[$metric]}
        result=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name "$metric" \
            --dimensions Name=FunctionName,Value="$fn" \
            --start-time "$start_time" --end-time "$end_time" \
            --period 2592000 --statistics "$statistic" \
            | jq -r ".Datapoints[].$statistic")

        # Special handling for rounding Duration to nearest whole number
        if [[ "$metric" == "Duration" && -n "$result" ]]; then
            result=$(echo "$result" | awk '{printf "%d\n", $1 + 0.5}')
        fi

        # Append metric result to output string
        metrics_output+="$result, "
    done

    # Trim trailing comma and space from metrics output string
    metrics_output=$(echo "$metrics_output" | sed 's/, $//')

    # Print the metrics for the function
    if [[ -n "$metrics_output" ]]; then
        echo "$fn, $metrics_output"
    fi
done