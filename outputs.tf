output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web-server.public_ip
}


output "instance_public_dns" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web-server.public_dns
}
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.nlb.dns_name
}

output "ssh_connection_command" {
  description = "SSH command to connect via NLB"
  value       = "ssh -p 2000 -i keys/aws_key spiderman@${aws_lb.nlb.dns_name}"
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution for the static website"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket hosting static content"
  value       = aws_s3_bucket.static_web_site_bucket.bucket
}

output "cloudfront_url" {
  description = "The full URL to access the static website via CloudFront"
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}