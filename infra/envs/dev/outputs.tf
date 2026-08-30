output "vpc_id" {
  description = "ID of the dev VPC"
  value       = aws_vpc.main.id
}

output "db_endpoint" {
  description = "Endpoint of the direct RDS PostgreSQL instance"
  value       = aws_db_instance.dev.endpoint
}

output "db_proxy_endpoint" {
  description = "Endpoint of the RDS Proxy"
  value       = aws_db_proxy.dev.endpoint
}

output "staging_bucket_name" {
  description = "Name of the S3 staging bucket"
  value       = aws_s3_bucket.staging.id
}

output "spa_url" {
  description = "HTTPS URL of the CloudFront SPA distribution"
  value       = "https://${aws_cloudfront_distribution.spa.domain_name}"
}