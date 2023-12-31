#!/usr/bin/env bash

export AWS_PAGER=""

# Create an array to hold all role data
roles_data=()

# List all roles
roles=$(aws iam list-roles --query 'Roles[*].RoleName' --output text)

# Iterate over each role
for role in $roles; do
    role_data="{\"RoleName\": \"$role\", \"Policies\": []}"

    # List attached managed policies for the role
    managed_policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[*].PolicyArn' --output text)
    for policy_arn in $managed_policies; do
        # Get the policy version
#        policy_version=$(aws iam get-policy --policy-arn "$policy_arn" --query 'Policy.DefaultVersionId' --output text)
        # Get the policy document
        policy_document=$(aws iam get-policy-version --policy-arn "$policy_arn" --version-id "$policy_version" --query 'PolicyVersion.Document' --output json)
#        role_data=$(jq --argjson pd "$policy_document" --arg pa "$policy_arn" '.Policies += [{"PolicyArn": $pa, "Document": $pd}]' <<<"$role_data")
    done

#    # List inline policies for the role
#    inline_policies=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text)
#    for policy_name in $inline_policies; do
#        # Get the policy document
#        policy_document=$(aws iam get-role-policy --role-name "$role" --policy-name "$policy_name" --query 'PolicyDocument' --output json)
#        role_data=$(jq --argjson pd "$policy_document" --arg pn "$policy_name" '.Policies += [{"PolicyName": $pn, "Document": $pd}]' <<<"$role_data")
#    done
#
#    # Add the role data to the roles array
#    roles_data+=("$role_data")
done

# Combine all role data into a single JSON array
printf '%s\n' "${roles_data[@]}" | jq -s .
