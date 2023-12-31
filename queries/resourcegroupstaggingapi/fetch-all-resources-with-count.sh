#!/usr/bin/env bash

aws resourcegroupstaggingapi get-resources | jq -r '.ResourceTagMappingList[].ResourceARN' | \
awk -F '[:/]' '
    {
        if ($3 == "s3") {
            count["s3"]++
        } else if ($3 == "sns") {
            count["sns"]++
        } else {
            count[$3]++
        }
    }
    END {
        for (service in count) {
            print "Service: " service ", Count: " count[service]
        }
    }
'
