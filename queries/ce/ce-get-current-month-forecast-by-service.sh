#!/usr/bin/env bash

set -e

start_of_month=$(date -u "+%Y-%m-01")
current_day=$(date -u "+%Y-%m-%d" -d "yesterday")
end_of_month=$(date -u "+%Y-%m-%d" -d "$(date -u +'%Y-%m-01') +1 month -1 day")

current_costs=$(aws ce get-cost-and-usage --time-period Start=$start_of_month,End=$current_day --granularity MONTHLY --metrics "AmortizedCost" --group-by Type="DIMENSION",Key="SERVICE")

echo "$current_costs" | jq -c '.ResultsByTime[].Groups[]' | while IFS= read -r line; do
    service=$(echo "$line" | jq -r '.Keys[0]')
    current_cost=$(echo "$line" | jq -r '.Metrics.AmortizedCost.Amount | tonumber')

    # Construct the filter JSON
    filter_json=$(jq -n --arg service "$service" '{"Dimensions": {"Key": "SERVICE", "Values": [$service]}}')

    forecast=$(aws ce get-cost-forecast --time-period Start="$current_day",End="$end_of_month" --granularity MONTHLY --metric "AMORTIZED_COST" --filter "$filter_json")
    forecast_cost=$(echo "$forecast" | jq -r '.Total.Amount | tonumber')

    combined_cost=$(jq -n "$current_cost + $forecast_cost")

    echo "Service: $service, Current Cost: $current_cost, Forecast Cost: $forecast_cost, Combined Cost: $combined_cost"
done

