#!/bin/bash

set -e 

REGION="us-east-1"
ACCOUNT_ID="225387892229"
REPO="my-ecr-repository"
TAG="latest"

echo "Logging into ECR..."
aws ecr get-login-password --region $REGION \
| docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo "Pulling latest image..."
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG

echo "Stopping old container (if exists)..."
docker rm -f my-app || true

echo "Running new container..."
docker run -d -p 3000:3000 --name my-app \
$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG

echo "Deployment successful and running on port 3000"