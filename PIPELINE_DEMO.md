# Event-Driven Pipeline Demo

End-to-end walkthrough: write a prompt → upload to S3 → Lambda processes it → read the AI response.

---

## Prerequisites

- AWS CLI installed and configured (`aws configure`)
- Infrastructure deployed (`terraform apply` completed)
- Note your bucket name from the Terraform output:
  ```bash
  terraform -chdir=terraform output bucket_name
  ```

---

## Step 1 — Write a Prompt to a `.txt` File

```bash
echo "Explain the concept of blue/green deployments and when to use them." > prompt.txt
```

Or write a multi-line prompt:

```bash
cat > prompt.txt << 'EOF'
What is Kubernetes and how does it handle container orchestration?
Include an explanation of pods, services, and deployments.
EOF
```

Verify the file:

```bash
cat prompt.txt
```

---

## Step 2 — Upload the File to S3

```bash
aws s3 cp prompt.txt s3://simpleqna-ai-processing/input/prompt.txt
```

Expected output:

```
upload: ./prompt.txt to s3://simpleqna-ai-processing/input/prompt.txt
```

This upload immediately triggers the Lambda function via the S3 event notification.

---

## Step 3 — Monitor Lambda Execution (Optional)

Watch the Lambda logs in real time:

```bash
aws logs tail /aws/lambda/simpleqna-prompt-processor --follow
```

You should see output similar to:

```
START RequestId: abc-123 ...
Processing prompt from input/prompt.txt: Explain the concept of blue/green...
Response written to s3://simpleqna-ai-processing/output/prompt_response.txt
END RequestId: abc-123 ...
```

Press `Ctrl+C` to stop tailing.

---

## Step 4 — Check the Output File

List the output folder to confirm the response file was created:

```bash
aws s3 ls s3://simpleqna-ai-processing/output/
```

Expected output:

```
2024-01-01 12:00:05    2048 prompt_response.txt
```

---

## Step 5 — Read the AI Response

Print the response directly to the terminal:

```bash
aws s3 cp s3://simpleqna-ai-processing/output/prompt_response.txt -
```

Or download it locally:

```bash
aws s3 cp s3://simpleqna-ai-processing/output/prompt_response.txt response.txt
cat response.txt
```

The output file format:

```
=== Prompt ===
Explain the concept of blue/green deployments and when to use them.

=== AI Response ===
Blue/green deployment is a release strategy that reduces downtime and risk
by running two identical production environments...
```

---

## Full End-to-End One-Liner

```bash
echo "What is Infrastructure as Code?" > prompt.txt \
  && aws s3 cp prompt.txt s3://simpleqna-ai-processing/input/prompt.txt \
  && echo "Waiting for Lambda..." && sleep 15 \
  && aws s3 cp s3://simpleqna-ai-processing/output/prompt_response.txt -
```

---

## Listing All Inputs and Outputs

```bash
# All uploaded prompts
aws s3 ls s3://simpleqna-ai-processing/input/

# All generated responses
aws s3 ls s3://simpleqna-ai-processing/output/
```

---

## Cleanup

Remove specific files:

```bash
aws s3 rm s3://simpleqna-ai-processing/input/prompt.txt
aws s3 rm s3://simpleqna-ai-processing/output/prompt_response.txt
```

Remove all files in the bucket:

```bash
aws s3 rm s3://simpleqna-ai-processing --recursive
```

Tear down all infrastructure:

```bash
terraform -chdir=terraform destroy
```
