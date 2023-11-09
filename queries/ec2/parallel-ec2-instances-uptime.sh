#!/usr/bin/env bash

set -e


function get_uptime(){
  instance_id=$1
  current_time=$2
  previous_state=""
  uptime='unknown'
  while read -r event_time state; do
    state=${state//\'/}
    event_time_seconds=$(date -d "${event_time//\'/}" +%s)
    uptime=$(( (current_time - event_time_seconds) / 3600 ))
    if [[ -z "$previous_state" ]]; then
      previous_state="$state"
    fi
    if [[ "$previous_state" != "running" && "$state" == "running" ]]; then
        break
    fi
    previous_state="$state"
  done < <(aws configservice get-resource-config-history --resource-id "$instance_id" --resource-type AWS::EC2::Instance --limit 100 |
                   jq -r -c '.configurationItems[] | [.configurationItemCaptureTime, (.configuration | fromjson | .state.name)] | @sh')
  echo "$instance_id,$uptime"
}

export -f get_uptime

current_time=$(date +%s)

aws ec2 describe-instances --filter 'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].[InstanceId]' \
  --output text | sed 's/"//g' | \
    parallel --will-cite --jobs 5 --colsep ',' get_uptime {} "$current_time"