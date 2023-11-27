#!/usr/bin/env bash

start_of_month=$(date -u "+%Y-%m-01")
current_day=$(date -u "+%Y-%m-%d")
end_of_month=$(date -u -d "$(date -u +'%Y-%m-01') +1 month" +%Y-%m-%d)

current_costs=$(aws ce get-cost-and-usage --time-period Start=$start_of_month,End=$current_day --granularity MONTHLY --metrics "AmortizedCost" --group-by Type="DIMENSION",Key="SERVICE")

echo "$current_costs" | jq -c '.ResultsByTime[].Groups[]' | while IFS= read -r line; do
    service=$(echo "$line" | jq -r '.Keys[0]')
    current_cost=$(echo $line | jq -r '.Metrics.AmortizedCost.Amount')

    filter_json=$(jq -n --arg service "$service" '{"Dimensions": {"Key": "SERVICE", "Values": [$service]}}')
    forecast=$(aws ce get-cost-forecast --time-period Start="$current_day",End="$end_of_month" --granularity MONTHLY --metric "AMORTIZED_COST" --filter "$filter_json" 2>&1)

    if [[ $forecast == *"Insufficient amount of historical data"* ]]; then
        echo "$service, Insufficient historical data to generate forecast."
    else
        forecast_cost=$(echo "$forecast" | jq -r '.Total.Amount | tonumber')
        forecast_cost_rounded=$(printf "%.2f" "$forecast_cost")
        current_cost_rounded=$(printf "%.2f" "$current_cost")

        echo "$service, $forecast_cost_rounded, $current_cost_rounded"
    fi
done
