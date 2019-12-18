//TODO: maybe move to single repo using github pages
resource aws_s3_bucket "bucket" {
  bucket = "${var.app-name}-${var.account-id}"
  acl = "public-read"
}

resource aws_iam_role "iam_for_lambda" {
  name = "${var.app-name}-iam_for_lambda"
  permissions_boundary = "arn:aws:iam::876284459943:policy/iamRolePermissionBoundary"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource aws_iam_policy "s3-write-policy" {
  name = "${var.app-name}-s3"
  description = "A policy to allow write access to s3 to this bucket: ${var.app-name}-${var.account-id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "s3:PutObject",
            "s3:PutObjectAcl"
        ],
        "Resource": [
          "${aws_s3_bucket.bucket.arn}",
          "${aws_s3_bucket.bucket.arn}/*"
        ]
    }
  ]
}
EOF
}

resource aws_iam_policy "ec2-network-interface-policy" {
  name = "${var.app-name}-ec2"
  description = "A policy to allow create, describe, and delete network interfaces"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

//TODO: remove this policy once we get params out of ssm and into env.
resource aws_iam_policy "ssm-get-parameters-policy" {
  name = "${var.app-name}-ssm"
  description = "A policy to allow getting parameters from the parameter store"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ssm:getParameters"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3-policy-attachment" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.s3-write-policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2-network-interface-policy-attachment" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.ec2-network-interface-policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm-policy-attachment" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.ssm-get-parameters-policy.arn
}

resource aws_lambda_permission "allow_cloudwatch" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.batch_job.arn
}

resource "aws_security_group" "vpc_sec" {
  name = "${var.app-name}-sg"
  description = "${var.app-name}-sg"
  vpc_id = var.vpc-id

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = true
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_lambda_function "lambda" {
  function_name = var.app-name
  filename = var.path-to-jar
  memory_size = var.memory
  description = var.lambda-description
  role = aws_iam_role.iam_for_lambda.arn
  handler = var.handler
  runtime = var.runtime
  timeout = var.timeout
  vpc_config {
    security_group_ids = ["${aws_security_group.vpc_sec.id}"]
    subnet_ids = var.subnets
  }
  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.bucket.id
      HANDEL_PARAMETER_STORE_PREFIX = var.app-name
    }
  }
}

resource aws_cloudwatch_event_rule "batch_job" {
  name = var.app-name
  description = var.cron-description
  schedule_expression = var.cron-expression
}

resource aws_cloudwatch_event_target "event_targets" {
  target_id = "run-scheduled-task-every-day"
  arn = aws_lambda_function.lambda.arn
  rule = aws_cloudwatch_event_rule.batch_job.name
}
