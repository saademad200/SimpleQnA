output "bucket_name" {
  description = "S3 bucket used for prompt inputs and AI response outputs"
  value       = aws_s3_bucket.ai_processing.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.ai_processing.arn
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.prompt_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.prompt_processor.arn
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance running the backend"
  value       = aws_instance.backend.public_ip
}

output "backend_url" {
  description = "Backend API base URL (used by Lambda)"
  value       = "http://${aws_instance.backend.public_ip}:8000"
}

output "upload_instructions" {
  description = "How to trigger the pipeline"
  value       = "Upload a .txt file to s3://${aws_s3_bucket.ai_processing.bucket}/input/<filename>.txt"
}
