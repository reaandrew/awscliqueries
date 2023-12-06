#!/bin/bash

json_output=$(aws ce get-cost-and-usage --time-period Start=$(date -d "-6 months" +%Y-%m-01),End=$(date +%Y-%m-%d) --granularity MONTHLY --metrics "AmortizedCost" --group-by Type=DIMENSION,Key=SERVICE | jq -r '.ResultsByTime[] | .TimePeriod.Start as $date | .Groups[] | [$date, .Keys[], (.Metrics.AmortizedCost.Amount // 0 | tostring)] | @tsv' | sed 's/"//g')

dates=$(echo "$json_output" | cut -f1 | uniq | sort -t'-' -k1,1 -k2,2 | awk -F'-' '{printf "%02d/%s\n", $2, substr($1,3,2)}')

echo "$json_output" | awk -v dates="$dates" -F'\t' '
BEGIN {
    split(dates, date_arr, "\n")
    for (i in date_arr) {
        ordered_dates[i] = date_arr[i]
    }
    max_resource_len = 0
}

{
    date = substr($1, 6, 2) "/" substr($1, 3, 2)
    resource = $2
    cost = ($3 == "" ? "0" : $3)
    costs[resource, date] = sprintf("%.2f", cost + 0.0)  # Handle empty and round to 2 decimal places
    resources[resource]
    if (length(resource) > max_resource_len) {
        max_resource_len = length(resource)
    }
}
END{
    print "Contents of costs array:"
    for (r in resources) {
        for (d in ordered_dates) {
            cost_to_print=(costs[r, ordered_dates[d]] == "" ? "0" : costs[r, ordered_dates[d]])
            print "Resource: " r ", Date: " ordered_dates[d] ", Cost: " cost_to_print
        }
    }
}'
