#!/bin/bash

start_time="$(date -u -d '1 month ago' '+%Y-%m-%dT%H:%M:%SZ')"
end_time="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "Function, Avg Duration, Sum Invocations, Sum Errors, Avg Cold Start Duration, Max Memory, Max Concurrent Executions, Sum Throttles"
# List all Lambda functions and use jq to parse the output
aws lambda list-functions | jq -r '.Functions[].FunctionName' | while read -r fn; do
    # Retrieve the average duration for each function over the last month
    average_duration=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Duration \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Average \
        | jq -r '.Datapoints[].Average')

    invocation_count=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Invocations \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Sum  \
        | jq -r '.Datapoints[].Sum' )

    error_rate=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Errors \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Sum  \
        | jq -r '.Datapoints[].Sum' )

    cold_start_duration=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name InitDuration \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Average  \
        | jq -r '.Datapoints[].Average' )

    max_memory=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name MaxMemoryUsed \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Maximum  \
        | jq -r '.Datapoints[].Maximum' )

    max_concurrent_executions=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name ConcurrentExecutions \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Maximum  \
        | jq -r '.Datapoints[].Maximum' )

    sum_throttles=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Throttles \
        --dimensions Name=FunctionName,Value="$fn" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 2592000 --statistics Sum  \
        | jq -r '.Datapoints[].Sum' )

    # If average_duration is not empty, round to nearest whole number using awk
    if [ -n "$average_duration" ]; then
        rounded_duration=$(echo "$average_duration" | awk '{printf "%d\n", $1 + 0.5}')
        echo "$fn, $rounded_duration ms, $invocation_count, $error_rate, $cold_start_duration, $max_memory, $max_concurrent_executions, $sum_throttles"
    fi
done
