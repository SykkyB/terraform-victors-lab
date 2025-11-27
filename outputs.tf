############################################################
# OUTPUTS
############################################################

# ---------------- Network Load Balancer (NLB) ----------------
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.nlb.dns_name
}

output "ssh_bastion_connection_command" {
  description = "SSH command to connect via NLB"
  value       = "ssh -p 2000 -i keys/aws_key ubuntu@${aws_lb.nlb.dns_name}"
}

output "ssh_webserver_via_bastion" {
  description = "SSH into a private webserver instance via NLB Bastion"
  value       = "ssh -i keys/aws_key -J ubuntu@${aws_lb.nlb.dns_name}:2000 spiderman@<private-ip-from-aws-console>"
}

# ---------------- S3 + CloudFront ----------------
output "s3_bucket_name" {
  description = "The name of the S3 bucket hosting static website content"
  value       = aws_s3_bucket.static_web_site_bucket.bucket
}

output "cloudfront_url" {
  description = "Full CloudFront website URL"
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}

# ---------------- Application Connection Info ----------------
output "alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = aws_lb.alb.dns_name
}

output "web_server_public_url" {
  description = "Public URL to access your private web server via ALB"
  value       = "http://${aws_lb.alb.dns_name}/index.php"
}

output "web_server_public_url_static" {
  description = "Public URL to access static content on ALB"
  value       = "http://${aws_lb.alb.dns_name}/"
}
