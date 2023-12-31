#!/usr/bin/env bash

aws resourcegroupstaggingapi get-resources | jq -r '.ResourceTagMappingList[].ResourceARN' | \
awk -F '[:/]' '
    {
        resourceType = "unknown"
        if ($3 == "s3") {
            resourceType = "bucket"
        } else if ($3 == "sns") {
            resourceType = "topic"
        } else {
            resourceType = $6  # Assuming $6 is the general case for resource type
        }

        # Construct a unique key for each service-resource pair
        pair = $3 ":" resourceType
        count[pair]++
    }
    END {
        for (pair in count) {
            split(pair, s, ":")  # Split the pair back into service and resource
            service = s[1]
            resource = s[2]
            print service "," resource "," count[pair]
        }
    }
'
