#!/bin/bash

AWS_REGION="us-east-1"
BUCKET_NAME="self-healing-ci-tfstate"
DYNAMODB_TABLE="self-healing-ci-terraform-state-lock"

echo "WARNING: This will destroy all Terraform state infrastructure!"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "Deleting all objects in S3 bucket..."
aws s3 rm s3://$BUCKET_NAME --recursive --region $AWS_REGION

echo "Deleting all object versions..."
aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --region $AWS_REGION \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' \
    --output json | \
    jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
    while read args; do
        aws s3api delete-object --bucket $BUCKET_NAME $args --region $AWS_REGION
    done

echo "Deleting all delete markers..."
aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --region $AWS_REGION \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
    --output json | \
    jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
    while read args; do
        aws s3api delete-object --bucket $BUCKET_NAME $args --region $AWS_REGION
    done

echo "Deleting S3 bucket..."
aws s3api delete-bucket \
    --bucket $BUCKET_NAME \
    --region $AWS_REGION

echo "Deleting DynamoDB table..."
aws dynamodb delete-table \
    --table-name $DYNAMODB_TABLE \
    --region $AWS_REGION

echo "Waiting for DynamoDB table deletion..."
aws dynamodb wait table-not-exists \
    --table-name $DYNAMODB_TABLE \
    --region $AWS_REGION

echo "Teardown complete!"
echo "You can now safely delete your Terraform files."