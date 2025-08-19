Param(
  [string]$Region = "us-east-1",
  [string]$Prefix = "dmc"
)

$ErrorActionPreference = "Stop"

# Rutas de plantillas (carpeta infra al lado de este script)
$InfraRoot = Join-Path (Get-Location) "infra"
$S3Tpl   = Join-Path $InfraRoot "s3-data-bucket.yaml"
$SQSTpl  = Join-Path $InfraRoot "sqs-queues.yaml"
$ConsTpl = Join-Path $InfraRoot "lambda-dynamo-s3-consumer.yaml"
$ApiTpl  = Join-Path $InfraRoot "apigw-lambda-sqs.yaml"

# Verifica archivos
foreach ($p in @($S3Tpl,$SQSTpl,$ConsTpl,$ApiTpl)) {
  if (-not (Test-Path $p)) { throw "No se encontró la plantilla: $p" }
}

# Nombres de stacks
$S3Stack   = "$Prefix-s3"
$SQSStack  = "$Prefix-sqs"
$ConsStack = "$Prefix-consumer"
$ApiStack  = "$Prefix-apigw"

Write-Host "Deploying S3..." -ForegroundColor Cyan
aws cloudformation deploy `
  --stack-name $S3Stack `
  --template-file $S3Tpl `
  --region $Region `
  --parameter-overrides Prefix=$Prefix

$BucketName = aws cloudformation describe-stacks --stack-name $S3Stack --region $Region `
  --query "Stacks[0].Outputs[?OutputKey=='BucketNameOut'].OutputValue" --output text
if (-not $BucketName) { throw "BucketNameOut no encontrado en $S3Stack" }

Write-Host "Deploying SQS..." -ForegroundColor Cyan
aws cloudformation deploy `
  --stack-name $SQSStack `
  --template-file $SQSTpl `
  --region $Region `
  --parameter-overrides Prefix=$Prefix

$QUrl = aws cloudformation describe-stacks --stack-name $SQSStack --region $Region `
  --query "Stacks[0].Outputs[?OutputKey=='QueueUrlOut'].OutputValue" --output text
$QArn = aws cloudformation describe-stacks --stack-name $SQSStack --region $Region `
  --query "Stacks[0].Outputs[?OutputKey=='QueueArnOut'].OutputValue" --output text
if (-not $QUrl -or -not $QArn) { throw "QueueUrlOut/QueueArnOut no encontrados en $SQSStack" }

Write-Host "Deploying Lambda consumer (SQS -> DynamoDB & S3)..." -ForegroundColor Cyan
aws cloudformation deploy `
  --stack-name $ConsStack `
  --template-file $ConsTpl `
  --region $Region `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides Prefix=$Prefix QueueArn="$QArn" S3BucketName="$BucketName"

Write-Host "Deploying API Gateway (POST -> Lambda -> SQS)..." -ForegroundColor Cyan
aws cloudformation deploy `
  --stack-name $ApiStack `
  --template-file $ApiTpl `
  --region $Region `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides Prefix=$Prefix QueueUrl="$QUrl" QueueArn="$QArn"

Write-Host "`nOutputs:" -ForegroundColor Yellow
aws cloudformation describe-stacks --stack-name $S3Stack   --region $Region --query "Stacks[0].Outputs" --output table
aws cloudformation describe-stacks --stack-name $SQSStack  --region $Region --query "Stacks[0].Outputs" --output table
aws cloudformation describe-stacks --stack-name $ConsStack --region $Region --query "Stacks[0].Outputs" --output table
aws cloudformation describe-stacks --stack-name $ApiStack  --region $Region --query "Stacks[0].Outputs" --output table
