#!/usr/bin/env bash

set -e

current_time=$(date +%s)

aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' | \
while read -r instance_id; do
  aws configservice get-resource-config-history --resource-type AWS::EC2::Instance --limit 1 |
    jq -c '.configurationItems[] | select(.resourceType=="AWS::EC2::Instance" and .configuration.state.name=="running") | [.configurationItemCaptureTime] | @sh' | \
    while read -r event_time; do
      event_time_seconds=$(date -d "$event_time" +%s)
      hours_diff=$(( (current_time - event_time_seconds) / 3600 ))
      echo "$instance_id, $hours_diff"
    done
  done