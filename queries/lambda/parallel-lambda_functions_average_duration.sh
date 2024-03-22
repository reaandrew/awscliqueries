#!/usr/bin/env bash

fetch_metrics() {
    fn="$1"
    start_time="$2"
    end_time="$3"
    metrics_output=""

    declare -A metric_statistics_map=(
        [Duration]="Average"
        [Invocations]="Sum"
        [Errors]="Sum"
        [InitDuration]="Average"
        [MaxMemoryUsed]="Maximum"
        [ConcurrentExecutions]="Maximum"
        [Throttles]="Sum"
    )

    for metric in "${!metric_statistics_map[@]}"; do
        statistic=${metric_statistics_map[$metric]}
        result=$(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name "$metric" \
            --dimensions Name=FunctionName,Value="$fn" \
            --start-time "$start_time" --end-time "$end_time" \
            --period 2592000 --statistics "$statistic" \
            | jq -r ".Datapoints[].$statistic")

        if [[ "$metric" == "Duration" && -n "$result" ]]; then
            result=$(echo "$result" | awk '{printf "%d\n", $1 + 0.5}')
        fi

        metrics_output+="$result, "
    done

    metrics_output=$(echo "$metrics_output" | sed 's/, $//')
    if [[ -n "$metrics_output" ]]; then
        echo "$fn, $metrics_output"
    fi
}
export -f fetch_metrics


start_time="$(date -u -d '1 month ago' '+%Y-%m-%dT%H:%M:%SZ')"
end_time="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "Function, Avg Duration, Sum Invocations, Sum Errors, Avg Cold Start Duration, Max Memory, Max Concurrent Executions, Sum Throttles"

aws lambda list-functions | jq -r '.Functions[].FunctionName' | \
  parallel --will-cite --jobs 10 fetch_metrics {} "$start_time" "$end_time"
