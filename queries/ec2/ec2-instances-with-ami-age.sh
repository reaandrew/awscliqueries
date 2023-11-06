#!/bin/bash

# Set the desired AWS region
region="your-region" # replace with your region like us-east-1, us-west-2, etc.

# List all EC2 instances in the region and get their AMI IDs
aws ec2 describe-instances --region "$region" \
    --query 'Reservations[*].Instances[*].[InstanceId, ImageId]' \
    --output text | while read -r instance_id ami_id
do
    # Get the details of the AMI including creation date, owner ID, and name
    ami_details=$(aws ec2 describe-images --region "$region" \
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
          echo "Instance ID: $instance_id, AMI ID: $ami_id, AMI Age: $age_days days, Owner ID: $owner_id, AMI Name: $name"
    done
done
