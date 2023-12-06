#!/usr/bin/env bash

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
    costs[resource, date] = sprintf("%.2f", cost + 0.0)
    resources[resource]
    if (length(resource) > max_resource_len) {
        max_resource_len = length(resource)
    }
}

END {
    value_col_width=10
    # Determine column width for resources
    resource_col_width = max_resource_len + 2

    # Header: Resource names
    printf "%-" resource_col_width "s", "Resource"
    for (i = 1; i <= length(ordered_dates); i++) {
        printf "%-" value_col_width "s", ordered_dates[i]
    }
    print ""

    # Data: Costs by resource and date
    for (resource in resources) {
        printf "%-" resource_col_width "s", resource
        for (i = 1; i <= length(ordered_dates); i++) {
            printf "%-" value_col_width "s", (costs[resource, ordered_dates[i]] == "" ? "0.00" : costs[resource, ordered_dates[i]])
        }
        print ""
    }
}'
