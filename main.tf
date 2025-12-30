############################################################
# DATA SOURCES
############################################################

# Get availability zones for the region
data "aws_availability_zones" "available" {}

data "sops_file" "secrets" {
  source_file = "${path.module}/terraform.tfvars.enc"
  input_type  = "yaml"
}

locals {
  secrets = data.sops_file.secrets.data

  # shortcut aliases
  db_user     = local.secrets.db_user
  db_password = local.secrets.db_password
  db_name     = local.secrets.db_name
}
############################################################
# VPC AND SUBNETS
############################################################

# VPC
resource "aws_vpc" "victors_lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "victors_lab_vpc" }
}

# Public subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.victors_lab_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "public subnet" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.victors_lab_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-2" }
}

resource "aws_subnet" "public_3" {
  vpc_id                  = aws_vpc.victors_lab_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-3" }
}


# Private subnets
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.victors_lab_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "private subnet" }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.victors_lab_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false
  tags                    = { Name = "private-subnet-2" }
}

resource "aws_subnet" "private_3" {
  vpc_id                  = aws_vpc.victors_lab_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = { Name = "private-subnet-3" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.victors_lab_vpc.id
  tags   = { Name = "victors_lab_igw" }
}

# NAT Gateway for private subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "victors_lab_nat" }
}

############################################################
# ROUTE TABLES
############################################################

# Public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.victors_lab_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_3_assoc" {
  subnet_id      = aws_subnet.public_3.id
  route_table_id = aws_route_table.public_rt.id
}

# Private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.victors_lab_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_3_assoc" {
  subnet_id      = aws_subnet.private_3.id
  route_table_id = aws_route_table.private_rt.id
}

############################################################
# KEY PAIR
############################################################

resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}

############################################################
# SECURITY GROUPS
############################################################

# Bastion Security Group
resource "aws_security_group" "sg_bastion" {
  description = "Bastion SG"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    description     = "Allow SSH from NLB"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.sg_nlb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web server security group (SSH/HTTP/HTTPS)
resource "aws_security_group" "sg_ssh" {
  description = "Allow SSH and ICMP from Bastion"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    description     = "Allow SSH from bastion"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.sg_bastion.id]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

# HTTP/HTTPS SG
resource "aws_security_group" "sg_web_ingress" {
  description = "Allow HTTP/HTTPS from allowed CIDR"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    description = "HTTP from allowed CIDR"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "HTTPS from allowed CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-ingress-sg"
  }
}

# ALB Security Group
resource "aws_security_group" "sg_alb" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS from Internet"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    description = "Allow HTTP from anywhere"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }

  tags = { Name = "alb-sg" }
}

# ALB -> Web server rules
resource "aws_security_group_rule" "allow_alb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_ssh.id
  source_security_group_id = aws_security_group.sg_alb.id
}

resource "aws_security_group_rule" "allow_alb_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_ssh.id
  source_security_group_id = aws_security_group.sg_alb.id
}

# RDS Security Group
resource "aws_security_group" "sg_rds" {
  name        = "rds-sg"
  description = "Allow Postgres from web-server"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.sg_ssh.id]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NLB SG for SSH forwarding
resource "aws_security_group" "sg_nlb" {
  description = "Allow inbound on port 2000"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    description = "Allow SSH forwarding"
    protocol    = "tcp"
    from_port   = 2000
    to_port     = 2000
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

############################################################
# COMPUTE
############################################################

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg_bastion.id]

  tags = { Name = "bastion-host", os = "ubuntu-22" }
}

############################################################
# LOAD BALANCERS
############################################################

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "web-server-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id, aws_subnet.public_3.id]
  security_groups    = [aws_security_group.sg_alb.id]

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = { Name = "web-server-alb" }
}

# ALB Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-server-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.victors_lab_vpc.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}


# NLB for SSH forwarding
resource "aws_lb" "nlb" {
  name               = "ssh-forward-nlb"
  load_balancer_type = "network"
  subnets            = [aws_subnet.public.id]
  security_groups    = [aws_security_group.sg_nlb.id]
}

resource "aws_lb_target_group" "ssh_target" {
  name        = "ssh-target"
  port        = 22
  protocol    = "TCP"
  vpc_id      = aws_vpc.victors_lab_vpc.id
  target_type = "instance"
}

resource "aws_lb_target_group_attachment" "ssh_attachment_bastion" {
  target_group_arn = aws_lb_target_group.ssh_target.arn
  target_id        = aws_instance.bastion.id
  port             = 22
}

resource "aws_lb_listener" "ssh_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 2000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ssh_target.arn
  }
}

############################################################
# AUTOSCALING
############################################################

# Launch Template for web server
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-server-lt-"
  image_id      = var.instance_ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    security_groups = [
      aws_security_group.sg_ssh.id,
      aws_security_group.sg_web_ingress.id
    ]
  }

  user_data = base64encode(templatefile("${path.module}/apache-mkdocs.yaml.tpl", {
    db_user     = local.db_user
    db_password = local.db_password
    db_name     = local.db_name
    db_host     = aws_db_instance.postgres.address
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "autoscaled-web-server", os = "ubuntu-22" }
  }
}

# AutoScaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                      = "web-server-asg"
  max_size                  = 3
  min_size                  = 2
  desired_capacity          = 2
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = [aws_subnet.private.id, aws_subnet.private_2.id, aws_subnet.private_3.id]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "web-asg-instance"
    propagate_at_launch = true
  }
}

# Scaling Policy
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "web-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
}

# CloudWatch Alarm for scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]

  dimensions = { AutoScalingGroupName = aws_autoscaling_group.web_asg.name }
}

############################################################
# IAM
############################################################

# EC2 role for S3 access
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "ec2_s3_read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = [aws_s3_bucket.static_web_site_bucket.arn, "${aws_s3_bucket.static_web_site_bucket.arn}/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_profile"
  role = aws_iam_role.ec2_role.name
}

############################################################
# S3 AND CLOUDFRONT
############################################################

# S3 bucket for static content
resource "aws_s3_bucket" "static_web_site_bucket" {
  bucket = "alexrachok-terraform-web-site-static-content"
  tags   = { Name = "Static web site content" }
}

resource "aws_s3_bucket_ownership_controls" "s3_ownership_controls" {
  bucket = aws_s3_bucket.static_web_site_bucket.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_public_access_block" "s3_block_public_access" {
  bucket                  = aws_s3_bucket.static_web_site_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Objects
resource "aws_s3_object" "site1_image" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site1/images/test_site_image.jpg"
  source = "www_site1/test_site_image.jpg"
  etag   = filemd5("www_site1/test_site_image.jpg")
}

resource "aws_s3_object" "site2_image" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site2/images/crypto.jpg"
  source = "www_site2/crypto.jpg"
  etag   = filemd5("www_site2/crypto.jpg")
}

resource "aws_s3_object" "healthcheck_script" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site2/healthcheck_init.sh"
  source = "www_site2/healthcheck_init.sh"
  etag   = filemd5("www_site2/healthcheck_init.sh")
}

resource "aws_s3_object" "db_backup" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site2/db_backup.dump"
  source = "www_site2/my_backup.dump"
  etag   = filemd5("www_site2/my_backup.dump")
}

resource "aws_s3_object" "crypto_updater_script" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site2/crypto_updater.py"
  source = "www_site2/crypto_updater.py"
  etag   = filemd5("www_site2/crypto_updater.py")
}

# S3 objects from templates
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.static_web_site_bucket.bucket
  key          = "index.html"
  content      = templatefile("${path.module}/www_site1/index.html.tpl", { cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/" })
  content_type = "text/html"
  etag         = md5(templatefile("${path.module}/www_site1/index.html.tpl", { cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/" }))
}

resource "aws_s3_object" "php_index" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site2/index.php"
  content = templatefile("${path.module}/www_site2/index.php.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/",
    db_host        = aws_db_instance.postgres.address,
    db_name        = local.db_name,
    db_user        = local.db_user,
    db_pass        = local.db_password
  })
  content_type = "application/x-httpd-php"
  etag = md5(templatefile("${path.module}/www_site2/index.php.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/",
    db_host        = aws_db_instance.postgres.address,
    db_name        = local.db_name,
    db_user        = local.db_user,
    db_pass        = local.db_password
  }))
}

# CloudFront
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac-web-site"
  description                       = "Access control for CloudFront to read S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  depends_on = [
    aws_acm_certificate_validation.cloudfront_cert
  ]
  enabled             = true
  default_root_object = "index.html"

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  aliases = ["internet.sys-lab.xyz"]

  origin {
    domain_name              = aws_s3_bucket.static_web_site_bucket.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.s3_origin.id
  }

  logging_config {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "s3_origin" {
  name = "Managed-CORS-S3Origin"
}

# S3 Bucket Policy for CloudFront access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.static_web_site_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.static_web_site_bucket.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn } }
    }]
  })
}

############################################################
# DATABASE
############################################################

# DB Subnet Group - Places the RDS instance in private subnets across multiple AZs
resource "aws_db_subnet_group" "db_subnets" {
  name       = "postgress-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id, aws_subnet.private_3.id]

  tags = {
    Name = "db-subnet-group"
  }
}

# Postgres RDS Instance - Primary database for the application
resource "aws_db_instance" "postgres" {
  identifier        = "test-postgres-db"
  engine            = "postgres"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  username = local.db_user
  password = local.db_password
  db_name  = local.db_name

  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name

  skip_final_snapshot = true
}

############################################################
# VPC ENDPOINTS
############################################################

# S3 VPC Endpoint - Allows private access to S3 from within the VPC (no NAT gateway needed for S3 traffic)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.victors_lab_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = [aws_route_table.private_rt.id]

  # Note: S3 endpoints are gateway endpoints, so they use route tables
}

############################################################
# ROUTE53 & DNS SETUP
############################################################

# Hosted Zone Data Source - Main public zone for sys-lab.xyz
data "aws_route53_zone" "main" {
  name         = "sys-lab.xyz"
  private_zone = false
}

# DNS Record for CloudFront Distribution (internet.sys-lab.xyz)
resource "aws_route53_record" "cloudfront_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "internet.sys-lab.xyz"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# DNS Record for Application Load Balancer (crypto.sys-lab.xyz)
resource "aws_route53_record" "alb_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "crypto.sys-lab.xyz"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

############################################################
# ACM CERTIFICATES - ALB (Regional)
############################################################

# ACM Certificate for ALB (crypto.sys-lab.xyz) - Must be in the same region as the ALB
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = "crypto.sys-lab.xyz"
  validation_method = "DNS"
}

# DNS Validation Records for ALB Certificate
resource "aws_route53_record" "alb_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

# Complete Certificate Validation for ALB
resource "aws_acm_certificate_validation" "alb_cert_validation" {
  certificate_arn = aws_acm_certificate.alb_cert.arn

  validation_record_fqdns = [
    for r in aws_route53_record.alb_cert_validation : r.fqdn
  ]
}

############################################################
# ACM CERTIFICATES - CloudFront (us-east-1 only)
############################################################

# ACM Certificate for CloudFront - Must be created in us-east-1 regardless of main region
resource "aws_acm_certificate" "cloudfront_cert" {
  provider          = aws.us_east_1
  domain_name       = "sys-lab.xyz"
  validation_method = "DNS"

  subject_alternative_names = [
    "internet.sys-lab.xyz",
    "www.internet.sys-lab.xyz"
  ]
}

# DNS Validation Records for CloudFront Certificate
resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

# Complete Certificate Validation for CloudFront
resource "aws_acm_certificate_validation" "cloudfront_cert" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.cloudfront_cert.arn

  validation_record_fqdns = [
    for r in aws_route53_record.cloudfront_cert_validation : r.fqdn
  ]
}

############################################################
# APPLICATION LOAD BALANCER LISTENERS
############################################################

# HTTPS Listener - Terminates TLS and forwards to web target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = aws_acm_certificate.alb_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# HTTP Listener - Redirects all HTTP traffic to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1
  name     = "cloudfront-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cloudfrontWAF"
    sampled_requests_enabled   = true
  }
}

resource "aws_s3_bucket" "cloudfront_logs" {
  bucket        = "alexrachok-cloudfront-logs"
  force_destroy = true

  tags = {
    Name = "cloudfront-access-logs"
  }
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket                  = aws_s3_bucket.cloudfront_logs.id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}
