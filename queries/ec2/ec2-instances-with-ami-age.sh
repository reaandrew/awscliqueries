#!/bin/bash

# List all EC2 instances in the region and get their AMI IDs
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId, ImageId]' \
    --output text | while read -r instance_id ami_id
do
    # Get the details of the AMI including creation date, owner ID, and name
    ami_details=$(aws ec2 describe-images \
                    --image-ids "$ami_id" \
                    --query 'Images[*].[CreationDate,OwnerId,Name]' \
                    --output text) | \
    while read -r creation_date owner_id name
    do
          # Calculate the age of the AMI from the creation date
          ami_age=$(date -d "$creation_date" +%s)
          current_date=$(date +%s)
          age_days=$(( (current_date - ami_age) / 86400 ))

          # Output the instance ID, AMI ID, AMI age, owner ID, and AMI name
          echo "InstanceID, AmiID, AmiAge, DaysOld, OwnerID, Name"
          echo "$instance_id,$ami_id,$age_days, $owner_id, $name"
    done
done
