#!/usr/bin/env bash

set -e

aws rds describe-db-instances \
    --no-cli-pager \
    --query 'DBInstances[?StorageEncrypted==`false`].[DBInstanceIdentifier]' \
    --output text