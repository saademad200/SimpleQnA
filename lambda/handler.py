import json
import os
import urllib.request
import urllib.error
import boto3


def lambda_handler(event, context):
    s3 = boto3.client("s3")

    record = event["Records"][0]
    bucket_name = record["s3"]["bucket"]["name"]
    object_key = record["s3"]["object"]["key"]

    # Read the uploaded .txt file
    s3_response = s3.get_object(Bucket=bucket_name, Key=object_key)
    prompt_text = s3_response["Body"].read().decode("utf-8").strip()

    if not prompt_text:
        print(f"Empty file uploaded: {object_key}")
        return {"statusCode": 400, "body": "Empty prompt file"}

    print(f"Processing prompt from {object_key}: {prompt_text[:100]}...")

    # Call the backend API
    backend_url = os.environ["BACKEND_API_URL"].rstrip("/")
    api_url = f"{backend_url}/process-text"

    payload = json.dumps({"prompt_text": prompt_text}).encode("utf-8")
    req = urllib.request.Request(
        api_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode("utf-8"))
        ai_response = result["response"]
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        print(f"Backend API error {e.code}: {error_body}")
        raise RuntimeError(f"Backend returned {e.code}: {error_body}")
    except urllib.error.URLError as e:
        print(f"Failed to reach backend: {e.reason}")
        raise RuntimeError(f"Cannot reach backend at {backend_url}: {e.reason}")

    # Write response to output/ prefix in the same bucket
    filename = object_key.split("/")[-1]
    base_name = filename[:-4] if filename.endswith(".txt") else filename
    output_key = f"output/{base_name}_response.txt"

    output_content = (
        f"=== Prompt ===\n{prompt_text}\n\n=== AI Response ===\n{ai_response}"
    )

    s3.put_object(
        Bucket=bucket_name,
        Key=output_key,
        Body=output_content.encode("utf-8"),
        ContentType="text/plain",
    )

    print(f"Response written to s3://{bucket_name}/{output_key}")

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Processed successfully",
                "input_key": object_key,
                "output_key": output_key,
            }
        ),
    }
