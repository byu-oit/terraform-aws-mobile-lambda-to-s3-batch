output "lambda-sec-group" {
  value = aws_security_group.vpc_sec
}

output "lambda" {
  value = aws_lambda_function.lambda
}

output "bucket" {
  value = aws_s3_bucket.bucket
}
