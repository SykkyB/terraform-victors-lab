output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web-server.id
}

output "instance_az" {
  description = "Availability Zone of the EC2 instance"
  value       = aws_instance.web-server.availability_zone
}

output "instance_subnet" {
  description = "Subnet ID where the EC2 instance is deployed"
  value       = aws_instance.web-server.subnet_id
}

output "instance_security_group" {
  description = "Security group attached to EC2 instance"
  value       = aws_instance.web-server.vpc_security_group_ids
}

# ---------------- NLB ----------------

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.nlb.dns_name
}

output "ssh_bastion_connection_command" {
  description = "SSH command to connect via NLB"
  value       = "ssh -p 2000 -i keys/aws_key ubuntu@${aws_lb.nlb.dns_name}"
}

output "ssh-webserver_connection_command" {
  description = "SSH command to connect via NLB"
  value       = "ssh ubuntu@${aws_instance.web-server.private_ip}"
}

output "http_url_via_nlb" {
  description = "HTTP URL to access the web server through NLB"
  value       = "http://${aws_lb.nlb.dns_name}"
}

# ---------------- S3 + CloudFront ----------------

output "s3_bucket_name" {
  description = "The name of the S3 bucket hosting static website content"
  value       = aws_s3_bucket.static_web_site_bucket.bucket
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_url" {
  description = "Full CloudFront website URL"
  value       = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}

# ---------------- Application Connection Info ----------------

output "web_server_direct_http" {
  description = "Direct HTTP URL to EC2 (bypassing NLB)"
  value       = "http://${aws_instance.web-server.public_ip}"
}


output "web_server_connection_info" {
  description = "Summary of connection info for your web server"
  value = {
    nlb_url        = "http://${aws_lb.nlb.dns_name}"
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
  }
}
