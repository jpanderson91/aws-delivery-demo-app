"""
AWS ProServe Customer Management API
Demonstrates modern Python development for AWS Delivery Consultant role
Author: John Anderson
"""

import json
import boto3
import logging
from typing import Dict, Any, Optional
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
            customer_data.update({
                'customer_id': f"cust_{datetime.now().strftime('%Y%m%d%H%M%S')}",
                'created_at': datetime.now().isoformat(),
                'status': 'active'
            })
            
            # Store in DynamoDB
            response = self.table.put_item(Item=customer_data)
            
            logger.info(f"Customer created successfully: {customer_data['customer_id']}")
            return {
                'statusCode': 201,
                'body': json.dumps({
                    'message': 'Customer created successfully',
                    'customer_id': customer_data['customer_id']
                })
            }
            
        except ValueError as e:
            logger.error(f"Validation error: {str(e)}")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': str(e)})
            }
        except ClientError as e:
            logger.error(f"AWS service error: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Internal server error'})
            }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler demonstrating enterprise patterns:
    - CORS handling
    - Method routing
    - Error handling
    - Security headers
    """
    
    # CORS headers
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    try:
        http_method = event.get('httpMethod', '')
        table_name = ssm.get_parameter(Name='/demo-app/dynamodb/table-name')['Parameter']['Value']
        
        customer_service = CustomerService(table_name)
        
        if http_method == 'OPTIONS':
            return {'statusCode': 200, 'headers': headers}
        
        elif http_method == 'POST':
            body = json.loads(event.get('body', '{}'))
            result = customer_service.create_customer(body)
            result['headers'] = headers
            return result
            
        elif http_method == 'GET':
            # Implementation for retrieving customers
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'message': 'Customer retrieval endpoint'})
            }
        
        else:
            return {
                'statusCode': 405,
                'headers': headers,
                'body': json.dumps({'error': 'Method not allowed'})
            }
            
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Internal server error'})
        }
