#!/usr/bin/env bash

set -e

echo "InstanceID, AmiID, AmiAge, DaysOld, OwnerID, Name"

function describe_image(){
  instance_id=$1
  image_id=$2

  aws ec2 describe-images \
                  --image-ids "$image_id" \
                  --query 'Images[*].[CreationDate,OwnerId,Name]' \
                  --output text | \
    while read -r creation_date owner_id name
    do
          ami_age=$(date -d "$creation_date" +%s)
          current_date=$(date +%s)
          age_days=$(( (current_date - ami_age) / 86400 ))

          echo "$instance_id,$image_id,$age_days,$owner_id,$name"
    done
}

export -f describe_image

aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId, ImageId]' \
    --output json | jq -r '.[][] | @csv' | sed 's/"//g' | \
    parallel --will-cite --jobs 10 --colsep ',' get_describe_image