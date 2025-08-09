"""
AWS ProServe Customer Management API
Demonstrates modern Python development for AWS Delivery Consultant role
Author: John Anderson
"""

import json
import os
import boto3
import logging
from typing import Dict, Any
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS services
dynamodb = boto3.resource('dynamodb')
ssm = boto3.client('ssm')

class CustomerService:
    """
    Enterprise-grade customer service demonstrating:
    - Type safety and modern Python practices
    - Error handling and logging
    - AWS service integration
    - Security best practices
    """
    
    def __init__(self, table_name: str):
        self.table = dynamodb.Table(table_name)
        
    def create_customer(self, customer_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new customer with validation and error handling"""
        try:
            # Validate required fields
            required_fields = ['name', 'email', 'company']
            missing_fields = [field for field in required_fields if field not in customer_data]
            
            if missing_fields:
                raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")
            
            # Add metadata
            ttl_days = 0
            try:
                ttl_env = os.getenv('TTL_DAYS')
                if ttl_env is not None:
                    ttl_days = max(0, int(ttl_env))
            except Exception:
                ttl_days = 0
            expires_at = None
            if ttl_days > 0:
                # DynamoDB TTL expects a Unix epoch time in seconds (UTC)
                expires_at = int((datetime.utcnow().timestamp()) + (ttl_days * 86400))

            customer_data.update({
                'customer_id': f"cust_{datetime.now().strftime('%Y%m%d%H%M%S')}",
                'created_at': datetime.now().isoformat(),
                'status': 'active'
            })
            if expires_at is not None:
                customer_data['expires_at'] = expires_at
            
            # Store in DynamoDB
            self.table.put_item(Item=customer_data)
            
            logger.info("Customer created successfully: %s", customer_data['customer_id'])
            return {
                'statusCode': 201,
                'body': json.dumps({
                    'message': 'Customer created successfully',
                    'customer_id': customer_data['customer_id']
                })
            }
            
        except ValueError as e:
            logger.error("Validation error: %s", e)
            return {
                'statusCode': 400,
                'body': json.dumps({'error': str(e)})
            }
        except ClientError as e:
            logger.error("AWS service error: %s", e)
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }

    def list_customers(self, limit: int = 50) -> Dict[str, Any]:
        """Return up to `limit` customers from DynamoDB (scan for demo)."""
        try:
            limit = max(1, min(limit, 200))  # safety bounds
            response = self.table.scan(Limit=limit)
            items = response.get('Items', [])
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'count': len(items),
                    'items': items
                })
            }
        except ClientError as e:
            logger.error("AWS service error (scan): %s", e)
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }

def lambda_handler(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler demonstrating enterprise patterns:
    - CORS handling
    - Method routing
    - Error handling
    - Security headers
    """
    
    # CORS headers
    base_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }

    try:
        http_method = event.get('httpMethod', '')
        path = event.get('path', '/')
        # Normalize path to remove stage prefix (e.g., '/dev/customers' -> '/customers')
        norm_path = path
        if isinstance(path, str) and path.startswith('/'):
            parts = path.split('/', 2)
            # ['', 'stage', 'rest...'] -> keep rest...
            if len(parts) == 3 and parts[1] in {'dev', 'staging', 'prod'}:
                norm_path = '/' + parts[2]
        qs = event.get('queryStringParameters') or {}

        table_name = ssm.get_parameter(Name='/demo-app/dynamodb/table-name')['Parameter']['Value']
        customer_service = CustomerService(table_name)

        if http_method == 'OPTIONS':
            return {'statusCode': 200, 'headers': dict(base_headers)}

        # POST /customers -> create
        if http_method == 'POST' and norm_path.startswith('/customers'):
            body = json.loads(event.get('body', '{}'))
            result = customer_service.create_customer(body)
            result['headers'] = {**base_headers, 'Content-Type': 'application/json'}
            return result

        # GET /customers -> list
        if http_method == 'GET' and norm_path.startswith('/customers'):
            try:
                limit = int(qs.get('limit', '50'))
            except ValueError:
                limit = 50
            result = customer_service.list_customers(limit=limit)
            result['headers'] = {**base_headers, 'Content-Type': 'application/json'}
            return result

        # GET / -> return tiny HTML UI (no extra infra)
        if http_method == 'GET':
            html = r"""
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width,initial-scale=1"/>
    <title>Customer API Demo</title>
    <style>
        body{font-family:Segoe UI,Arial,sans-serif;background:#0f172a;color:#e2e8f0;margin:0;padding:24px}
        .card{background:#111827;border:1px solid #374151;border-radius:8px;padding:16px;max-width:860px;margin:0 auto}
        .row{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:12px}
        input{padding:8px;border-radius:6px;border:1px solid #374151;background:#0b1220;color:#e2e8f0}
        button{background:#f59e0b;color:#111827;border:none;border-radius:6px;padding:10px 14px;cursor:pointer}
        pre{background:#0b1220;border:1px solid #374151;border-radius:6px;padding:12px;overflow:auto}
        small{color:#94a3b8}
    </style>
    </head>
    <body>
        <div class="card">
            <h2>Customer API Demo</h2>
            <p><small>Use this page to create and list customers. This UI is served directly by Lambda (no S3/CloudFront).</small></p>
            <div class="row">
                <input id="name" placeholder="Name*"/>
                <input id="email" placeholder="Email*"/>
                <input id="company" placeholder="Company*"/>
                <button onclick="createCust()">Create</button>
                <button onclick="loadCust()">Refresh List</button>
            </div>
            <pre id="out">Loading...</pre>
        </div>
        <script>
            const base = window.location.origin + window.location.pathname.replace(/\/$/, '');
            const $ = (id) => document.getElementById(id);
            const setBusy = (busy) => {
                for (const b of document.querySelectorAll('button')) b.disabled = busy;
            };
            async function createCust(){
                const name = $('name').value.trim();
                const email = $('email').value.trim();
                const company = $('company').value.trim();
                if (!name || !email || !company) {
                    $('out').textContent = 'Please fill Name, Email, and Company.';
                    return;
                }
                try {
                    setBusy(true);
                    const body = { name, email, company };
                    const r = await fetch(base + '/customers', { method:'POST', headers:{ 'Content-Type':'application/json' }, body: JSON.stringify(body) });
                    const data = await r.json();
                    if (!r.ok) throw new Error(data.error || 'Request failed');
                    $('out').textContent = `Created customer: ${data.customer_id}`;
                    // Clear form and refresh list
                    $('name').value = '';
                    $('email').value = '';
                    $('company').value = '';
                    await loadCust();
                } catch (e) {
                    $('out').textContent = 'Error: ' + (e && e.message ? e.message : String(e));
                } finally {
                    setBusy(false);
                }
            }
            async function loadCust(){
                try {
                    setBusy(true);
                    const r = await fetch(base + '/customers?limit=25');
                    const data = await r.json();
                    $('out').textContent = JSON.stringify(data, null, 2);
                } catch (e) {
                    $('out').textContent = 'Error loading customers: ' + (e && e.message ? e.message : String(e));
                } finally {
                    setBusy(false);
                }
            }
            loadCust();
        </script>
    </body>
</html>
"""
            return {
                'statusCode': 200,
                'headers': {**base_headers, 'Content-Type': 'text/html; charset=utf-8'},
                'body': html
            }

        # Fallback
        return {
            'statusCode': 405,
            'headers': {**base_headers, 'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Method not allowed'})
        }

    except ValueError as e:
        logger.error("Bad request: %s", e)
        return {
            'statusCode': 400,
            'headers': {**base_headers, 'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Bad request'})
        }
    except ClientError as e:
        logger.error("AWS client error: %s", e)
        return {
            'statusCode': 500,
            'headers': {**base_headers, 'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
