# Architecture

```mermaid
flowchart LR
  A[Client/Browser] -- HTTPS --> B(API Gateway)
  B -- Lambda Proxy --> C[Lambda: customer_api.py]
  C -- Put/Query --> D[(DynamoDB: customers)]
  C -- GetParameter --> E[SSM Parameter Store]
```

- API Gateway exposes:
  - / (ANY + OPTIONS) → Lambda (for base URL test)
  - /customers (ANY + OPTIONS) → Lambda (POST creates customer)
- Lambda reads table name from SSM Parameter `/demo-app/dynamodb/table-name`.
- DynamoDB table name: `${project}-${env}-customers`.
