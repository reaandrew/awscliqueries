#!/usr/bin/env bash

start_of_month=$(date -u "+%Y-%m-01")
current_day=$(date -u "+%Y-%m-%d")
end_of_month=$(date -u "+%Y-%m-%d" -d "$(date -u +'%Y-%m-01') +1 month -1 day")

total_forecast=$(aws ce get-cost-forecast --time-period Start="$current_day",End="$end_of_month" --granularity MONTHLY --metric "AMORTIZED_COST" \
  jq -r '.Total.Amount')

echo "Total forecast cost: $total_forecast"

function get_forecast(){
  service="$1"
  filter_json=$(jq -n --arg service "$service" '{"Dimensions": {"Key": "SERVICE", "Values": [$service]}}')
      forecast=$(aws ce get-cost-forecast --time-period Start="$current_day",End="$end_of_month" --granularity MONTHLY --metric "AMORTIZED_COST" --filter "$filter_json" 2>&1)

      if [[ $forecast == *"Insufficient amount of historical data"* ]]; then
          echo "Service: $service, Error: Insufficient historical data to generate forecast."
      else
          forecast_cost=$(echo "$forecast" | jq -r '.Total.Amount | tonumber')
          echo "Service: $service, Forecast Cost: $forecast_cost"
      fi
}

export -f get_forecast

aws ce get-cost-and-usage --time-period Start="$start_of_month",End="$current_day" --granularity MONTHLY --metrics "AmortizedCost" --group-by Type="DIMENSION",Key="SERVICE" | \
   jq -r -c '.ResultsByTime[].Groups[] | .Keys[0] | @sh' | \
    parallel --will-cite --jobs 5 --colsep ',' get_forecast