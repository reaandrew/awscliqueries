#!/usr/bin/env bash

aws resourcegroupstaggingapi get-resources | jq '.ResourceTagMappingList[].ResourceARN' | \
 awk -F '[:/]' '
            {
                if ($3 == "s3") {
                    print "Service: " $3 ", Resource: bucket"
                } else if ($3 == "sns") {
                    print "Service: " $3 ", Resource: topic"
                } else {
                    print "Service: " $3 ", Resource: " $6
                }
            }
        '