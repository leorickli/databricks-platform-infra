import json
import os
import boto3

# Initialize the Kinesis client
kinesis_client = boto3.client('kinesis')
# Get the Kinesis stream name from the environment variables
STREAM_NAME = os.environ['KINESIS_STREAM_NAME']

def main(event, context):
    """
    This function receives a raw JSON payload from API Gateway, processes it,
    wraps it with API Gateway metadata, and puts the resulting record into a Kinesis stream.
    
    This version assumes the incoming payload is ALWAYS a raw JSON string (not Base64).
    """
    print("Received event (JSON payload) from API Gateway.")

    body = event.get('body')
    
    if not body:
        print("Error: Request body is empty.")
        return {
            'statusCode': 400,
            'body': json.dumps('Error: Request body is empty.')
        }

    # --- JSON Parsing ---
    try:
        data = json.loads(body)
        print("Successfully loaded JSON data.")
    except json.JSONDecodeError as e:
        print(f"Error: Body is not valid JSON. Error: {e}")
        print(f"First 200 chars of the body that failed parsing: {body[:200]}")
        return {
            'statusCode': 400,
            'body': json.dumps('Error: Invalid JSON format.')
        }

    # --- Kinesis Record Preparation ---
    try:
        # The incoming data can be a single record (dict) or multiple records (list).
        if isinstance(data, list):
            records_to_process = data
        elif isinstance(data, dict):
            records_to_process = [data]
        else:
            print(f"Error: Decoded data is not a list or a dictionary. Type is {type(data)}")
            return {'statusCode': 400, 'body': json.dumps('Error: Invalid data format.')}

        print(f"Processing {len(records_to_process)} records.")
        success_count = 0
        error_count = 0

        for idx, record in enumerate(records_to_process):
            if not isinstance(record, dict):
                print(f"Skipping item {idx} because it is not a dictionary: {type(record)}")
                error_count += 1
                continue

            # Use loggerImei as the partition key for even distribution in Kinesis.
            partition_key = str(record.get('loggerImei', 'unknown_logger'))
            
            # Wrap the original record with API Gateway metadata for tracking.
            payload_to_kinesis = {
                'clientId': event['requestContext'].get('identity', {}).get('apiKeyId', 'unknown'),
                'receivedAt': event['requestContext'].get('requestTimeEpoch'),
                'payload': record  # The original JSON record from the source
            }
            
            try:
                # Encode the final JSON object to UTF-8 bytes for Kinesis.
                kinesis_client.put_record(
                    StreamName=STREAM_NAME,
                    Data=json.dumps(payload_to_kinesis, ensure_ascii=False).encode('utf-8'),
                    PartitionKey=partition_key
                )
                success_count += 1
            except Exception as e:
                print(f"Error putting record {idx} (PartitionKey: {partition_key}) to Kinesis: {e}")
                error_count += 1

        print(f"Processing complete. Success: {success_count}, Errors: {error_count}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Processed {len(records_to_process)} records',
                'success': success_count,
                'errors': error_count
            })
        }

    except Exception as e:
        print(f"An unexpected error occurred during Kinesis processing: {e}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps(f'Internal server error: {str(e)}')
        }
