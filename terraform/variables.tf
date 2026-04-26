variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for prompt inputs and AI response outputs"
  type        = string
  default     = "simpleqna-ai-processing"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "simpleqna-prompt-processor"
}

variable "llm_api_key" {
  description = "Groq API key passed to the backend running on EC2"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "Public GitHub repo URL that EC2 will clone on startup"
  type        = string
  default     = "https://github.com/saademad200/SimpleQnA.git"
}

variable "system_prompt" {
  description = "System prompt passed to the LLM via the backend .env on EC2"
  type        = string
  default     = "You are an expert DevOps engineer who explains concepts clearly and concisely."
}

variable "backend_api_url" {
  description = "Override the backend URL used by Lambda. Defaults to the EC2 public IP resolved by Terraform."
  type        = string
  default     = ""
}
