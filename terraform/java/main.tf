# This file sets up all AWS resources for running and monitoring an AWS Lambda

# Create an S3 bucket and upload the zip with the compiled Lambda code to it (see aws_s3_object below)
# This step is not mandatory as the zip file could also be uploaded directly in the specification of the Lambda resource below.
# However, the documentation points out that uploading large files to S3 first and use the S3 object in the lambda will be beneficial for larger files
# as the S3 APIs are way more efficient in handling large files
# We follow the recommendation.
resource "aws_s3_bucket" "aws_s3_example_kafka_lambda_audit_log_bucket" {
  bucket = "${local.resource_prefix}-${var.aws_lambda_function_name}"

  tags = {
    Name        = "${local.resource_prefix}-${var.aws_lambda_function_name}"
    Environment = "Common"
  }
  lifecycle {
    prevent_destroy = false
  }
}

# We stick to the default setting of not enabling ACLs for the S3 bucket and stick to the default setting of only allowing explicitely granted access
resource "aws_s3_bucket_ownership_controls" "aws_s3_example_kafka_lambda_audit_log_bucket_acl_ownership" {
  bucket = aws_s3_bucket.aws_s3_example_kafka_lambda_audit_log_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# The following local file points to the zip file generated by gradle.
# We use this data entity mainly for calculating the base64sha256 hash below.
# We don't use it for accessing the content of that file (as this would output binary data to the console)
data "local_file" "example_kafka_lambda_audit_log_archive" {
    filename = "${path.module}/../../java/app/build/distributions/app.zip"
}

# Upload the zip file with the compiled Lambda to the S3 bucket
resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.aws_s3_example_kafka_lambda_audit_log_bucket.id
  key    = "app.zip"
  source = data.local_file.example_kafka_lambda_audit_log_archive.filename

  etag = data.local_file.example_kafka_lambda_audit_log_archive.content_base64sha256
}

# The log group to be used in CloudWatch. The name uses the standard prefix "/aws/lambda/" followed by the name of the Lambda
resource "aws_cloudwatch_log_group" "example_kafka_lambda_audit_log_log_group" {
  name              = "/aws/lambda/${var.aws_lambda_function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "aws_lambda_cloudwatch_audit_log_group" {
  name              = "${var.aws_lambda_cloudwatch_audit_log_group}"
  retention_in_days = 7
}

# The Lambda needs to have an execution role which acts as its identity at runtime. It is required for accessing additional AWS resources
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# The policy data for granting the Lambda access to CloudWatch in order to get log files.
# Note: We could have used the pre-defined role "AWSLambdaBasicExecutionRole" for this. But as an exercise, we state the allowec actions explicitely below.
# Note: We had to extend the ARN of the log group by ":*" in order to make the policy work as expected (otherwise no logs will be written to CloudWatch due to lack of permissions)
data "aws_iam_policy_document" "write_to_cloudwatch_policy_document" {
  // Allow lambda to write logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
        # First ARN specifies the log group used for logging the output (stdout and stderr) of the Lambda
        "${aws_cloudwatch_log_group.example_kafka_lambda_audit_log_log_group.arn}:*",
        # Second ARN specified the custom log group where the Lambda writes the auditlog event to
        "${aws_cloudwatch_log_group.aws_lambda_cloudwatch_audit_log_group.arn}:*"
    ]
  }
}

# This resource renders the policy data as json and actually grants the access permissions.
resource "aws_iam_policy" "write_to_cloudwatch_policy" {
    name = "${var.aws_lambda_function_name}_write_to_cloudwatch_policy"

    policy = data.aws_iam_policy_document.write_to_cloudwatch_policy_document.json
}

# This policy data configure read access to a specific secret in the AWS Secret Manager where we store our API key for consuming from Kafka
data "aws_iam_policy_document" "get_kafka_secret_from_secret_manager_policy_document" {
  // Allow lambda to write logs
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
        aws_secretsmanager_secret.example_kafka_lambda_audit_log_secret_consumer.arn
    ]
  }
}

# This resource renders the policy data as json and actually grants the access permissions.
resource "aws_iam_policy" "get_kafka_secret_from_secret_manager_policy" {
    name = "${local.resource_prefix}-${var.aws_lambda_function_name}_get_kafka_secret_from_secret_manager_policy"

    policy = data.aws_iam_policy_document.get_kafka_secret_from_secret_manager_policy_document.json
}

# Here, we combine the assume role and all additional policies in one iam role
resource "aws_iam_role" "example_kafka_lambda_audit_log_iam" {
  name               = "${local.resource_prefix}-${var.aws_lambda_function_name}_iam"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [
    aws_iam_policy.write_to_cloudwatch_policy.arn,
    aws_iam_policy.get_kafka_secret_from_secret_manager_policy.arn
  ]
}

resource "aws_lambda_function" "example_kafka_lambda_audit_log" {
  s3_bucket =  aws_s3_bucket.aws_s3_example_kafka_lambda_audit_log_bucket.id
  s3_key = aws_s3_object.lambda_app.key
  function_name = var.aws_lambda_function_name
  role          = aws_iam_role.example_kafka_lambda_audit_log_iam.arn
  handler       = var.aws_lambda_handler_class_name

  source_code_hash = data.local_file.example_kafka_lambda_audit_log_archive.content_base64sha256

  runtime = "java21"

  depends_on = [ 
    aws_cloudwatch_log_group.example_kafka_lambda_audit_log_log_group, 
    aws_iam_policy.write_to_cloudwatch_policy
  ]

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# We want the lambda to be called each time an event is received via Kafka
resource "aws_lambda_event_source_mapping" "example_kafka_lambda_audit_log_trigger" {
  function_name     = aws_lambda_function.example_kafka_lambda_audit_log.arn
  topics            = [var.ccloud_cluster_audit_log_topic]
  starting_position = "TRIM_HORIZON"
  enabled = var.aws_lambda_trigger_enabled

  self_managed_event_source {
    endpoints = {
      KAFKA_BOOTSTRAP_SERVERS = var.ccloud_audit_log_bootstrap_server
    }
  }
  self_managed_kafka_event_source_config {
    consumer_group_id = "consumer-aws"
  }
  # Configure basic authentication and use the generated API key we store in the AWS Secret Manager in the next step
  source_access_configuration {
    type = "BASIC_AUTH"
    uri = aws_secretsmanager_secret.example_kafka_lambda_audit_log_secret_consumer.arn
  }
}

# Create a secret in the AWS Secret Manager
resource "aws_secretsmanager_secret" "example_kafka_lambda_audit_log_secret_consumer" {
  name = "${local.resource_prefix}-${var.aws_lambda_function_name}_secret"
}

# Store the generated Kafka API key for the consumer in AWS secret manager
resource "aws_secretsmanager_secret_version" "example_kafka_lambda_audit_log_secret_consumer_value" {
  secret_id     = aws_secretsmanager_secret.example_kafka_lambda_audit_log_secret_consumer.id
  secret_string = jsonencode(
    {
      "username": "${var.ccloud_audit_log_api_key.key}",
      "password": "${var.ccloud_audit_log_api_key.secret}"
    }
  )
}
