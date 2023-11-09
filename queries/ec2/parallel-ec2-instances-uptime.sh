#!/usr/bin/env bash

set -e


function get_uptime(){
  instance_id=$1
  current_time=$2
  aws configservice get-resource-config-history --resource-id "$instance_id" --resource-type AWS::EC2::Instance --limit 1 |
      jq -r -c '.configurationItems[] | [.configurationItemCaptureTime] | @sh' | \
      while read -r event_time; do
        event_time_seconds=$(date -d "${event_time//\'/}" +%s)
        hours_diff=$(( (current_time - event_time_seconds) / 3600 ))
        echo "$instance_id,$hours_diff"
      done
}

export -f get_uptime

current_time=$(date +%s)

aws ec2 describe-instances --filter 'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].[InstanceId]' \
  --output text | sed 's/"//g' | \
    parallel --will-cite --jobs 5 --colsep ',' get_uptime {} "$current_time"