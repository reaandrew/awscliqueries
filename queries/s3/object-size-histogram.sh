#!/usr/bin/env bash

set -e

bucket_name="$1"
aws s3api list-objects-v2 --bucket "$bucket_name" --query 'Contents[].Size' --output text | tr '\t' '\n' | \
awk '{
  if ($1 >= 0 && $1 < 1024) bin["0-1KB"]++;
  else if ($1 < 10240) bin["1KB-10KB"]++;
  else if ($1 < 102400) bin["10KB-100KB"]++;
  else if ($1 < 1024000) bin["100KB-1MB"]++;
  else if ($1 < 10240000) bin["1MB-10MB"]++;
  else if ($1 < 102400000) bin["10MB-100MB"]++;
  else bin["100MB+"]++;
}
END {
  for (b in bin) {
    print b ": " bin[b]
  }
}'
