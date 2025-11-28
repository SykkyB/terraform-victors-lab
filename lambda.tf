############################################################
# LOCALS
############################################################

locals {
  layer_key    = "lambda/layers/lambda_layer.zip"
  function_key = "lambda/functions/crypto_updater.zip"
  lambda_name  = "crypto-updater"
}

############################################################
# S3 OBJECTS FOR LAMBDA
############################################################

# Upload Lambda Layer ZIP
resource "aws_s3_object" "lambda_layer_zip" {
  bucket     = var.lambda_bucket_name
  key        = local.layer_key
  source     = "www_site2/lambda/lambda_layer.zip"
  etag       = filemd5("www_site2/lambda/lambda_layer.zip")
  depends_on = [aws_s3_bucket.static_web_site_bucket]
}

# Upload Lambda Function ZIP
resource "aws_s3_object" "lambda_function_zip" {
  bucket     = var.lambda_bucket_name
  key        = local.function_key
  source     = "www_site2/lambda/crypto_updater.zip"
  etag       = filemd5("www_site2/lambda/crypto_updater.zip")
  depends_on = [aws_s3_bucket.static_web_site_bucket]
}

############################################################
# IAM ROLE AND POLICIES FOR LAMBDA
############################################################

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "crypto_updater_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC access policy
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom inline policy for S3 and CloudWatch logs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.lambda_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["s3:GetObject"],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::${var.lambda_bucket_name}/*"
      }
    ]
  })
}

############################################################
# LAMBDA LAYER
############################################################

resource "aws_lambda_layer_version" "crypto_layer" {
  layer_name          = "crypto-updater-layer"
  s3_bucket           = var.lambda_bucket_name
  s3_key              = local.layer_key
  compatible_runtimes = ["python3.12"]

  depends_on = [aws_s3_object.lambda_layer_zip]
}

############################################################
# LAMBDA FUNCTION
############################################################

resource "aws_lambda_function" "crypto_updater" {
  function_name = local.lambda_name
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  s3_bucket = var.lambda_bucket_name
  s3_key    = local.function_key
  role      = aws_iam_role.lambda_role.arn

  layers  = [aws_lambda_layer_version.crypto_layer.arn]
  timeout = 60

  environment {
    variables = {
      DB_HOST = aws_db_instance.postgres.address
      DB_NAME = local.db_name
      DB_USER = local.db_user
      DB_PASS = local.db_password
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private.id, aws_subnet.private_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_s3_object.lambda_function_zip,
    aws_lambda_layer_version.crypto_layer
  ]
}

############################################################
# CLOUDWATCH EVENTS TO TRIGGER LAMBDA
############################################################

# CloudWatch Event Rule (scheduled every 5 minutes)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "crypto-updater-schedule"
  schedule_expression = "rate(5 minutes)"
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "crypto-updater"
  arn       = aws_lambda_function.crypto_updater.arn
}

# Permission for CloudWatch to invoke Lambda
resource "aws_lambda_permission" "lambda_schedule_permission" {
  statement_id  = "allow_cloudwatch_invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crypto_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}

############################################################
# SECURITY GROUP FOR LAMBDA
############################################################

resource "aws_security_group" "lambda_sg" {
  name        = "lambda_sg"
  description = "Allow Lambda to access RDS"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  # Lambda needs full outbound access to RDS and S3
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
