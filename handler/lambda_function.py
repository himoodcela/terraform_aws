import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
bucket_name = 'your-bucket-name'

def lambda_handler(event, context):
    logger.info("Start handler")

    try:
        response = s3_client.list_objects_v2(Bucket=bucket_name)
        photos = [item['Key'] for item in response.get('Contents', [])]
    except Exception as e:
        return err_response(500, str(e))
    
    return response(200, photos)

def response(status_code, data):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(data),
        "isBase64Encoded": False
    }

def err_response(status_code, message):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({"message": message}),
        "isBase64Encoded": False
    }
