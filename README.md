# AWS Delivery Consultant Demo Application

Full-stack serverless demo: API Gateway → Lambda (Python) → DynamoDB, provisioned with Terraform. Designed for quick deploys and portfolio-ready screenshots.

## Architecture

```mermaid
flowchart LR
    A[Client/Browser] -- HTTPS --> B(API Gateway)
    B -- Proxy --> C[Lambda: customer_api.py]
    C -- Put/Query --> D[(DynamoDB: customers)]
    C -- GetParameter --> E[SSM Parameter: /demo-app/dynamodb/table-name]
```

## Validation screenshots

Below are validation screenshots from a live deployment of the basic serverless stack.

1) Terraform outputs
![Terraform Outputs](docs/screenshots/terraform-outputs.png)

2) API GET /
![GET Root](docs/screenshots/api-get-root.png)

3) API POST /customers
![POST Customer](docs/screenshots/api-post-customer.png)

4) DynamoDB scan
![DynamoDB Scan](docs/screenshots/dynamodb-scan.png)

5) Lambda logs (last 10 minutes)
![Lambda Logs](docs/screenshots/lambda-logs.png)

## Live HTML UI (served by Lambda)

The API root (GET /) returns a minimal HTML page to create and list customers—no S3/CloudFront required. Below is a sample flow from a live deployment.

1) Enter customer details and click Create
![Create Customer UI](docs/screenshots/ui-create-customer.png)

2) Success response with generated customer_id
![Create Success Message](docs/screenshots/ui-success-message.png)

3) Refreshed list including the new record
![Refreshed Customer List](docs/screenshots/ui-refreshed-list.png)

Tip: Save your screenshots with the above filenames into `docs/screenshots/` to render them here.

## Console verification

Spot-checks from the AWS Console for the same deployment:

1) API Gateway
- Overview: ![API Gateway](docs/screenshots/api-gateway.png)
- Resources: ![API Resources](docs/screenshots/api-gateway-resources.png)
- Stages: ![API Stages](docs/screenshots/api-gateway-stages.png)

2) Lambda Function
- Function details: ![Lambda Function](docs/screenshots/lambda-function.png)
- Code tab: ![Lambda Function Console](docs/screenshots/lambda-function-console-screenshot.png)

3) DynamoDB Table
- Table list/details: ![DynamoDB](docs/screenshots/dynamodb.png)
- Console view: ![DynamoDB Console](docs/screenshots/dynamodb-console-screenshot.png)
- Sample scan output: ![DynamoDB Scan](docs/screenshots/dynamodb-scan.png)

4) CloudWatch Logs
- Log group: ![CloudWatch Logs Group](docs/screenshots/cloudwatch-loggroup-console-screenshot.png)
- Recent Lambda logs: ![Lambda Logs](docs/screenshots/lambda-logs.png)

5) SSM Parameter Store
- Parameter list: ![SSM Parameter Store](docs/screenshots/ssm-parameter-store.png)
- Console view: ![SSM Parameter Store Console](docs/screenshots/ssm-parameter-store-console-screenshot.png)

## Quick start

Prereqs: AWS CLI v2, Terraform 1.5+, an AWS profile (SSO or static).

```powershell
cd terraform
terraform init
terraform apply -auto-approve
terraform output -raw api_invoke_url

# Test POST
$base = terraform output -raw api_invoke_url
$body = @{ name = "Jane Doe"; email = "jane@example.com"; company = "Acme Corp" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$base/customers" -ContentType 'application/json' -Body $body
```

### Quick smoke test

Run an end-to-end smoke test against the deployed API:

```powershell
pwsh -File .\testing\integration\smoke.ps1
```

## Repository layout

```
src/
    frontend/index.html
    lambda/customer_api.py
terraform/
    main.tf
    variables.tf
    outputs.tf
docs/
    PROJECT_STATUS.md
```

## Notes
- CORS preflight (OPTIONS) enabled for / and /customers.
- Lambda runtime: python3.11. Uses AWS SDK provided by environment.
- SSM Parameter stores the DynamoDB table name.

## Cleanup
```powershell
cd terraform
terraform destroy -auto-approve
```
