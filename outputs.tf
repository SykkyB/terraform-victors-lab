############################################################
# OUTPUTS
############################################################

# ---------------- Load Balancers ----------------

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer (SSH Bastion)"
  value       = aws_lb.nlb.dns_name
}

# ---------------- SSH ----------------

output "ssh_bastion_command" {
  description = "SSH command to connect to Bastion via NLB"
  value       = "ssh -p 2000 -i keys/aws_key ubuntu@${aws_lb.nlb.dns_name}"
}

output "ssh_webserver_via_bastion" {
  description = "SSH into a private webserver instance via NLB Bastion"
  value       = "ssh -i keys/aws_key -J ubuntu@${aws_lb.nlb.dns_name}:2000 spiderman@<private-ip-from-aws-console>"
}


# ---------------- CloudFront & S3 ----------------

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_url" {
  description = "Public CloudFront URL"
  value       = "https://internet.sys-lab.xyz/"
}

output "s3_bucket_name" {
  description = "S3 bucket for static website content"
  value       = aws_s3_bucket.static_web_site_bucket.bucket
}

# ---------------- Application ----------------

output "alb_application_url" {
  description = "Application URL via ALB (crypto site)"
  value       = "https://crypto.sys-lab.xyz/"
}

# ---------------- Database ----------------

output "rds_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = aws_db_instance.postgres.address
}

############################################################
# DNS (Custom Domains)
############################################################

output "cloudfront_custom_domain" {
  description = "Custom domain pointing to CloudFront (static website)"
  value       = "https://internet.sys-lab.xyz"
}

output "alb_custom_domain" {
  description = "Custom domain pointing to Application Load Balancer (app)"
  value       = "https://crypto.sys-lab.xyz"
}