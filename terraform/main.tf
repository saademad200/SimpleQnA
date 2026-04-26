terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# S3 bucket
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "ai_processing" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Project = "SimpleQnA"
  }
}

resource "aws_s3_bucket_versioning" "ai_processing" {
  bucket = aws_s3_bucket.ai_processing.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "ai_processing" {
  bucket                  = aws_s3_bucket.ai_processing.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────
# IAM role for Lambda
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.lambda_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = "SimpleQnA"
  }
}

# Allow Lambda to write CloudWatch logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to read from and write to the S3 bucket
data "aws_iam_policy_document" "lambda_s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.ai_processing.arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "${var.lambda_function_name}-s3-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_s3_access.json
}

# ─────────────────────────────────────────────
# Lambda function (packaged from ../lambda/)
# ─────────────────────────────────────────────

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda/handler.zip"
}

resource "aws_lambda_function" "prompt_processor" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 90
  memory_size      = 256

  environment {
    variables = {
      BACKEND_API_URL = var.backend_api_url != "" ? var.backend_api_url : "http://${aws_instance.backend.public_ip}:8000"
    }
  }

  tags = {
    Project = "SimpleQnA"
  }
}

# CloudWatch log group for Lambda (explicit so Terraform can manage retention)
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 7
}

# ─────────────────────────────────────────────
# S3 → Lambda trigger
# ─────────────────────────────────────────────

# Give S3 permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prompt_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ai_processing.arn
}

# S3 event notification: trigger Lambda on every .txt upload under input/
resource "aws_s3_bucket_notification" "prompt_upload_trigger" {
  bucket = aws_s3_bucket.ai_processing.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.prompt_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/"
    filter_suffix       = ".txt"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
