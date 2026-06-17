data "archive_file" "lambda_placeholder_zip" {
  type        = "zip"
  source_dir  = "python/lambda/"
  output_path = "python/lambda/lambda_handler.zip"
}

resource "aws_lambda_function" "data_decode" {
  function_name    = "lmx-decode-stream-data"
  role             = aws_iam_role.lambda_processor_role.arn
  filename         = data.archive_file.lambda_placeholder_zip.output_path
  source_code_hash = data.archive_file.lambda_placeholder_zip.output_base64sha256
  handler          = "lambda_handler.main"
  runtime          = "python3.13"

  environment {
    variables = {
      LOG_LEVEL = "info"
      # Stream paused 2026-05-18 (see kinesis.tf). Literal kept so the Lambda
      # still deploys; it will fail to PutRecord until the stream is restored.
      KINESIS_STREAM_NAME = "lmx-kinesis-acme-ingestion"
    }
  }
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_decode.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
