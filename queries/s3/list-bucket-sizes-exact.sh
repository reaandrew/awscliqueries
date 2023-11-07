#!/usr/bin/env bash

set -e

aws s3api list-buckets | jq -r '.Buckets[] | .Name' | \
while read -r bucketName;
do
  echo "$bucketName,$(aws s3 ls "s3://$bucketName" --recursive --summarize --human-readable | grep "Total Size" | cut -d: -f2)"
done
