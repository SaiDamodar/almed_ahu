#!/bin/bash
# AWS Infrastructure Setup Script
# This script deploys the CloudFormation template and sets up AWS IoT infrastructure

set -e

echo "=========================================="
echo "AWS IoT Infrastructure Setup"
echo "=========================================="

# Configuration
STACK_NAME="almed-ahu-infrastructure"
REGION="ap-south-1"
PROJECT_NAME="almed-ahu"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

echo "✓ AWS credentials configured"

# Deploy CloudFormation stack
echo ""
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file cloudformation-template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        ProjectName=$PROJECT_NAME \
        Region=$REGION \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✓ CloudFormation stack deployed successfully"
else
    echo "✗ CloudFormation deployment failed"
    exit 1
fi

# Get stack outputs
echo ""
echo "Getting stack outputs..."
IOT_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`IoTEndpoint`].OutputValue' \
    --output text)

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

echo ""
echo "=========================================="
echo "SETUP COMPLETE - SAVE THESE VALUES:"
echo "=========================================="
echo "IoT Endpoint: $IOT_ENDPOINT"
echo "User Pool ID: $USER_POOL_ID"
echo "User Pool Client ID: $USER_POOL_CLIENT_ID"
echo ""
echo "Next steps:"
echo "1. Create IoT Thing for each ESP32 device"
echo "2. Generate device certificates"
echo "3. Update ESP32 code with endpoint and certificates"
echo "4. Update Flutter app with User Pool ID and Client ID"
echo "=========================================="

