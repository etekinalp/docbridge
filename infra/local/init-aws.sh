#!/bin/bash
echo "Initializing LocalStack S3 and SQS resources..."
awslocal s3 mb s3://docbridge-staging-dev
awslocal sqs create-queue --queue-name docbridge-job-fanout-dev
awslocal sqs create-queue --queue-name docbridge-task-delivery-dev
awslocal sqs create-queue --queue-name docbridge-task-dlq-dev
