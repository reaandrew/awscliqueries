#!/usr/bin/env bash

set -e

function get_average_bucket_size(){
  bucketName=$1

  size=$(aws cloudwatch get-metric-statistics --namespace AWS/S3 \
      --start-time $(date -d '1 month ago' +%Y-%m-%dT%H:%M:%SZ) \
      --end-time $(date +%Y-%m-%dT%H:%M:%SZ) \
      --period 31536000 \
      --statistics Average \
      --metric-name BucketSizeBytes \
      --dimensions Name=BucketName,Value="$bucketName" Name=StorageType,Value=StandardStorage \
      --output json)

      size_in_bytes=$(jq 'if .Datapoints == [] then 0 else .Datapoints[0].Average end' <<< "$size")
      echo -e "$bucketName,$(echo "scale=2; $size_in_bytes / (1024 * 1024 * 1024)" | bc) GB"
}

export -f get_average_bucket_size

aws s3api list-buckets | jq -r '.Buckets[] | .Name' | sed 's/"//g' | \
  parallel --will-cite --jobs 10 --colsep ',' get_average_bucket_size
