#!/usr/bin/env bash

set -e

current_time=$(date +%s)

aws ec2 describe-instances --filter 'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].[InstanceId]' \
  --output text | \
    while read -r instance_id; do
      previous_state=""
      while read -r event_time state; do
        state=${state//\'/}
        if [[ -z "$previous_state" ]]; then
          previous_state="$state"
        fi
        if [[ "$previous_state" != "running" && "$state" == "running" ]]; then
            event_time_seconds=$(date -d "${event_time//\'/}" +%s)
            uptime=$(( (current_time - event_time_seconds) / 3600 ))
            echo "$instance_id,$uptime"
            break
        fi
        previous_state="$state"
      done < <(aws configservice get-resource-config-history --resource-id "$instance_id" --resource-type AWS::EC2::Instance --limit 100 |
                       jq -r -c '.configurationItems[] | [.configurationItemCaptureTime, (.configuration | fromjson | .state.name)] | @sh')
    done

