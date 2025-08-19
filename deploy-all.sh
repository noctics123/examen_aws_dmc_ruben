#!/usr/bin/env bash
set -euo pipefail

REGION="${1:-us-east-1}"
PREFIX="${2:-dmc}"

INFRA_DIR="$(pwd)/infra"

S3_TPL="${INFRA_DIR}/s3-data-bucket.yaml"
KDS_TPL="${INFRA_DIR}/kds-stream.yaml"
LD_TPL="${INFRA_DIR}/lambda-dynamo-consumer.yaml"
FH_TPL="${INFRA_DIR}/firehose-to-s3.yaml"

for p in "$S3_TPL" "$KDS_TPL" "$LD_TPL" "$FH_TPL"; do
  [[ -f "$p" ]] || { echo "No se encontró la plantilla: $p"; exit 1; }
done

S3_STACK="${PREFIX}-s3"
KDS_STACK="${PREFIX}-kds"
LD_STACK="${PREFIX}-lambda-dynamo"
FH_STACK="${PREFIX}-firehose"

echo "Deploying S3..."
aws cloudformation deploy \
  --stack-name "${S3_STACK}" \
  --template-file "${S3_TPL}" \
  --region "${REGION}" \
  --parameter-overrides Prefix="${PREFIX}"

BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "${S3_STACK}" --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='BucketNameOut'].OutputValue" --output text)
[[ -n "${BUCKET_NAME}" ]] || { echo "BucketNameOut no encontrado en ${S3_STACK}"; exit 1; }

echo "Deploying KDS..."
aws cloudformation deploy \
  --stack-name "${KDS_STACK}" \
  --template-file "${KDS_TPL}" \
  --region "${REGION}"

KINESIS_ARN=$(aws cloudformation describe-stacks --stack-name "${KDS_STACK}" --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='KinesisStreamArnOut'].OutputValue" --output text)
[[ -n "${KINESIS_ARN}" ]] || { echo "KinesisStreamArnOut no encontrado en ${KDS_STACK}"; exit 1; }

echo "Deploying Lambda + DynamoDB..."
aws cloudformation deploy \
  --stack-name "${LD_STACK}" \
  --template-file "${LD_TPL}" \
  --region "${REGION}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides Prefix="${PREFIX}" KinesisStreamArn="${KINESIS_ARN}"

echo "Deploying Firehose..."
aws cloudformation deploy \
  --stack-name "${FH_STACK}" \
  --template-file "${FH_TPL}" \
  --region "${REGION}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides Prefix="${PREFIX}" BucketName="${BUCKET_NAME}"

echo
echo "Outputs:"
for S in "${S3_STACK}" "${KDS_STACK}" "${LD_STACK}" "${FH_STACK}"; do
  aws cloudformation describe-stacks --stack-name "$S" --region "${REGION}" --query "Stacks[0].Outputs" --output table
done
