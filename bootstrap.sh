#!/bin/bash

aws s3api create-bucket \
  --bucket hameds-eks-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket hameds-eks-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name hameds-eks-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "done"
