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
