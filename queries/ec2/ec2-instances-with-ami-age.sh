#!/usr/bin/env bash

set -e

echo "InstanceID, AmiID, AmiAge, DaysOld, OwnerID, Name"

aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId, ImageId]' \
    --output text | while read -r instance_id ami_id
do
    aws ec2 describe-images \
                    --image-ids "$ami_id" \
                    --query 'Images[*].[CreationDate,OwnerId,Name]' \
                    --output text | \
      while read -r creation_date owner_id name
      do
            ami_age=$(date -d "$creation_date" +%s)
            current_date=$(date +%s)
            age_days=$(( (current_date - ami_age) / 86400 ))

            echo "$instance_id,$ami_id,$age_days, $owner_id, $name"
      done
done
