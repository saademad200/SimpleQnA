# SimpleQnA — AI DevOps Q&A Platform

A containerised AI Q&A application that exposes a **synchronous web UI** (Assignment 1) and an **event-driven S3 → Lambda processing pipeline** (Assignment 2).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Tech Stack](#tech-stack)
3. [Repository Structure](#repository-structure)
4. [Assignment 1 — Dockerised Application](#assignment-1--dockerised-application)
   - [Prerequisites](#prerequisites)
   - [Configuration](#configuration)
   - [Running Locally](#running-locally)
   - [API Reference](#api-reference)
5. [Assignment 2 — Event-Driven Pipeline (AWS)](#assignment-2--event-driven-pipeline-aws)
   - [How It Works](#how-it-works)
   - [Prerequisites (AWS)](#prerequisites-aws)
   - [Deploy with Terraform](#deploy-with-terraform)
   - [Triggering the Pipeline](#triggering-the-pipeline)
   - [Reading the Output](#reading-the-output)
   - [Terraform Resources](#terraform-resources)
6. [Environment Variables](#environment-variables)

---

## Architecture Overview

### Assignment 1 — Local Docker Stack

```
Browser
  │
  ▼
┌─────────────────┐       ┌──────────────────────┐       ┌──────────────┐
│  Frontend       │──────▶│  Backend (FastAPI)    │──────▶│  PostgreSQL  │
│  (Streamlit)    │       │  :8000               │       │  :5432       │
│  :8501          │◀──────│                      │       └──────────────┘
└─────────────────┘       │  POST /process-text  │──────▶  Groq LLM API
                          └──────────────────────┘        (llama-3.3-70b)
```

### Assignment 2 — AWS Event-Driven Pipeline

```
User uploads .txt file
        │
        ▼
┌───────────────────┐
│  S3 Bucket        │  input/<filename>.txt
│  (input/ prefix)  │
└────────┬──────────┘
         │  S3 ObjectCreated event
         ▼
┌───────────────────┐
│  AWS Lambda       │  reads file content (prompt)
│  (Python 3.12)    │
└────────┬──────────┘
         │  POST /process-text
         ▼
┌───────────────────┐
│  Backend API      │  calls Groq LLM, returns AI response
│  (FastAPI)        │
└────────┬──────────┘
         │  AI response
         ▼
┌───────────────────┐
│  S3 Bucket        │  output/<filename>_response.txt
│  (output/ prefix) │
└───────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Streamlit |
| Backend | FastAPI + Uvicorn (Python 3.9) |
| Database | PostgreSQL 15 |
| LLM | Groq API — `llama-3.3-70b-versatile` |
| Containerisation | Docker + Docker Compose |
| Cloud Storage | AWS S3 |
| Serverless Compute | AWS Lambda (Python 3.12) |
| Infrastructure as Code | Terraform ≥ 1.3 |
| Monitoring | CloudWatch Logs (Lambda) |

---

## Repository Structure

```
.
├── backend/
│   ├── Dockerfile
│   ├── main.py            # FastAPI app (endpoints + LLM integration)
│   └── requirements.txt
├── frontend/
│   ├── Dockerfile
│   ├── app.py             # Streamlit UI
│   └── requirements.txt
├── database/
│   └── init.sql           # Schema + seed data (5 DevOps prompts)
├── lambda/
│   └── handler.py         # Lambda function — reads S3, calls API, writes response
├── terraform/
│   ├── main.tf            # S3, Lambda, IAM, S3 notification
│   ├── variables.tf       # Input variables
│   └── outputs.tf         # Useful post-deploy values
├── docker-compose.yml
├── .env                   # Local secrets (not committed)
└── .gitignore
```

---

## Assignment 1 — Dockerised Application

### Prerequisites

- Docker ≥ 24
- Docker Compose ≥ 2
- A [Groq API key](https://console.groq.com/) (free tier available)

### Configuration

Create a `.env` file in the project root:

```env
LLM_API_KEY=your_groq_api_key_here
```

All other variables are pre-configured in `docker-compose.yml`.

### Running Locally

```bash
# Build and start all three services
docker compose up --build

# Run in the background
docker compose up --build -d

# Stop everything
docker compose down
```

| Service | URL |
|---|---|
| Frontend (Streamlit) | http://localhost:8501 |
| Backend (FastAPI docs) | http://localhost:8000/docs |
| PostgreSQL | localhost:5432 |

### API Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/ids` | List all prompt IDs in the database |
| `GET` | `/prompt/{id}` | Retrieve the text of a specific prompt |
| `POST` | `/process/{id}` | Run a database prompt through the LLM |
| `POST` | `/process-text` | Run any raw text through the LLM (used by Lambda) |

**`POST /process-text` request body:**

```json
{
  "prompt_text": "Explain what Kubernetes is."
}
```

**Response:**

```json
{
  "response": "Kubernetes is an open-source container orchestration platform..."
}
```

---

## Assignment 2 — Event-Driven Pipeline (AWS)

### How It Works

1. A `.txt` file containing a prompt is uploaded to the S3 bucket under the `input/` prefix.
2. S3 fires an `ObjectCreated` event and invokes the Lambda function.
3. Lambda downloads the file and reads the prompt text.
4. Lambda calls `POST /process-text` on the backend API.
5. The backend calls the Groq LLM and returns the AI response.
6. Lambda writes the result to `output/<filename>_response.txt` in the same S3 bucket.

### Prerequisites (AWS)

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.3
- AWS CLI configured with credentials (`aws configure`)
- Your GitHub repository must be **public** (EC2 clones it on startup)

### Deploy with Terraform

Everything — EC2 instance, S3 bucket, Lambda, IAM roles, and S3 event trigger — is provisioned by Terraform. No manual steps required.

Create `terraform/terraform.tfvars`:

```hcl
llm_api_key = "your_groq_api_key_here"

# Optional overrides (defaults shown)
# aws_region      = "us-east-1"
# bucket_name     = "simpleqna-ai-processing"
# github_repo     = "https://github.com/saademad200/SimpleQnA.git"
```

Then deploy:

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

Terraform will:
1. Launch an EC2 `t3.micro` instance (Amazon Linux 2023)
2. Bootstrap it via `user_data`: installs Docker + Compose, clones your repo, writes `.env`, runs `docker compose up -d`
3. Create the S3 bucket
4. Deploy the Lambda function with `BACKEND_API_URL` automatically set to the EC2 public IP
5. Wire the S3 `input/*.txt` trigger to Lambda

**Outputs after apply:**

```
backend_url          = "http://<ec2-public-ip>:8000"
bucket_name          = "simpleqna-ai-processing"
ec2_public_ip        = "<ec2-public-ip>"
lambda_function_name = "simpleqna-prompt-processor"
upload_instructions  = "Upload a .txt file to s3://simpleqna-ai-processing/input/<filename>.txt"
```

> The EC2 instance takes ~2 minutes after `apply` to finish its startup script (Docker install + image pull). The Lambda pipeline will work as soon as that completes.

### Triggering the Pipeline

```bash
# Write a prompt to a file
echo "What is the difference between blue/green and canary deployments?" > my_prompt.txt

# Upload to the input prefix — this triggers Lambda automatically
aws s3 cp my_prompt.txt s3://simpleqna-ai-processing/input/my_prompt.txt
```

### Reading the Output

Lambda writes the response within a few seconds. Retrieve it with:

```bash
# Download the response file
aws s3 cp s3://simpleqna-ai-processing/output/my_prompt_response.txt .

# Or print it directly
aws s3 cp s3://simpleqna-ai-processing/output/my_prompt_response.txt -
```

The output file format:

```
=== Prompt ===
What is the difference between blue/green and canary deployments?

=== AI Response ===
Blue/green deployment involves maintaining two identical environments...
```

To view Lambda logs:

```bash
aws logs tail /aws/lambda/simpleqna-prompt-processor --follow
```

### Terraform Resources

| Resource | Type | Purpose |
|---|---|---|
| `simpleqna-ai-processing` | `aws_s3_bucket` | Stores input prompts and output responses |
| `simpleqna-prompt-processor` | `aws_lambda_function` | Processes uploaded files |
| `simpleqna-prompt-processor-role` | `aws_iam_role` | Lambda execution role |
| `simpleqna-prompt-processor-s3-policy` | `aws_iam_role_policy` | Grants Lambda S3 GetObject + PutObject |
| `AWSLambdaBasicExecutionRole` | `aws_iam_role_policy_attachment` | Grants Lambda CloudWatch logging |
| `/aws/lambda/simpleqna-prompt-processor` | `aws_cloudwatch_log_group` | Lambda logs (7-day retention) |
| S3 notification | `aws_s3_bucket_notification` | Fires Lambda on `input/*.txt` uploads |
| `simpleqna-backend` | `aws_instance` | EC2 t3.micro running the full Docker stack |
| `simpleqna-backend-sg` | `aws_security_group` | Allows inbound on port 8000 and 22 |

### Teardown

```bash
cd terraform
terraform destroy
```

---

## Environment Variables

### Backend (Docker / `.env`)

| Variable | Required | Default | Description |
|---|---|---|---|
| `LLM_API_KEY` | Yes | — | Groq API key |
| `DATABASE_URL` | Yes | set in compose | PostgreSQL connection string |
| `LLM_API_URL` | No | `https://api.groq.com/openai/v1/chat/completions` | LLM endpoint |
| `LLM_MODEL` | No | `llama-3.3-70b-versatile` | Model name |
| `SYSTEM_PROMPT` | No | `You are a helpful DevOps assistant.` | System message sent to the LLM |

### Lambda (set automatically by Terraform)

| Variable | Description |
|---|---|
| `BACKEND_API_URL` | Set to `http://<ec2-public-ip>:8000` automatically from the EC2 resource |

### Terraform (`terraform.tfvars`)

| Variable | Required | Default | Description |
|---|---|---|---|
| `llm_api_key` | Yes | — | Groq API key — written to `.env` on EC2 |
| `aws_region` | No | `us-east-1` | AWS region for all resources |
| `bucket_name` | No | `simpleqna-ai-processing` | S3 bucket name |
| `github_repo` | No | `https://github.com/saademad200/SimpleQnA.git` | Repo cloned by EC2 on startup |
| `backend_api_url` | No | EC2 public IP | Override the Lambda backend URL |
