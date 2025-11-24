data "aws_availability_zones" "available" {

}

resource "aws_vpc" "victors_lab_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "victors_lab_vpc"
  }
}

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
  availability_zone       = data.aws_availability_zones.available.names[1] # second AZ
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-2" }
}

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

  tags = { Name = "private-subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.victors_lab_vpc.id
  tags   = { Name = "victors_lab_igw" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.victors_lab_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt"
  }
}


resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

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


resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "victors_lab_nat"
  }
}


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

  ingress {
    description     = "Allow ping from bastion"
    protocol        = "icmp"
    from_port       = -1
    to_port         = -1
    security_groups = [aws_security_group.sg_bastion.id]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}


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

resource "aws_security_group" "sg_bastion" {
  description = "Bastion SG"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  # allow SSH from the NLB SG (NLB will forward from allowed_cidr)
  ingress {
    description     = "Allow SSH from NLB"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.sg_nlb.id]
  }

  # optional: allow SSH from your allowed_cidr directly (if you want direct SSH bypassing NLB)
  # ingress {
  #   description = "Allow SSH from admin CIDR (optional)"
  #   protocol    = "tcp"
  #   from_port   = 22
  #   to_port     = 22
  #   cidr_blocks = [var.allowed_cidr]
  # }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.sg_bastion.id
  ]

  tags = {
    Name = "bastion-host"
    os   = "ubuntu-22"
  }
}


resource "aws_instance" "web-server" {
  depends_on = [
    aws_db_instance.postgres,
    aws_s3_object.index,
    aws_s3_object.site1_image,
    aws_cloudfront_distribution.cdn
  ]

  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  subnet_id = aws_subnet.private.id

  vpc_security_group_ids = [
    aws_security_group.sg_ssh.id,
    aws_security_group.sg_https.id,
    aws_security_group.sg_http.id
  ]
  user_data = templatefile("${path.module}/apache-mkdocs.yaml.tpl", {
    db_user     = var.db_user
    db_password = var.db_password
    db_name     = var.db_name
    db_host     = aws_db_instance.postgres.address
  })
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "web-server"
    os   = "ubuntu-22"
  }
}

resource "aws_security_group" "sg_rds" {
  name        = "rds-sg"
  description = "Allow Postgres from web-server"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.sg_ssh.id] # web-server SG
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "sg_https" {
  description = "Allow HTTPS from allowed CIDR"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    cidr_blocks = [var.allowed_cidr]
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_security_group" "sg_http" {
  description = "Allow HTTP from allowed CIDR"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    cidr_blocks = [var.allowed_cidr]
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_security_group" "sg_alb" {
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS from Internet"
  vpc_id      = aws_vpc.victors_lab_vpc.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group_rule" "allow_alb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_ssh.id # private web-server SG
  source_security_group_id = aws_security_group.sg_alb.id
}

resource "aws_security_group_rule" "allow_alb_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_ssh.id # private web-server SG
  source_security_group_id = aws_security_group.sg_alb.id
}

resource "aws_lb" "alb" {
  name               = "web-server-alb"
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public.id,
    aws_subnet.public_2.id
  ]
  security_groups = [aws_security_group.sg_alb.id]

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name = "web-server-alb"
  }
}



resource "aws_lb_target_group" "web_tg" {
  name        = "web-server-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.victors_lab_vpc.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb_target_group_attachment" "web_attachment" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web-server.id
  port             = 80
}

resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}



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


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.victors_lab_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [
    aws_route_table.private_rt.id
  ]
}

resource "aws_s3_bucket" "static_web_site_bucket" {
  bucket = "alexrachok-terraform-web-site-static-content"

  tags = {
    Name = "Static web site content"
  }
}

resource "aws_s3_bucket_ownership_controls" "s3_ownership_controls" {
  bucket = aws_s3_bucket.static_web_site_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_public_access_block" "s3_block_public_access" {
  bucket = aws_s3_bucket.static_web_site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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


resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "index.html"
  content = templatefile("${path.module}/www_site1/index.html.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
  })
  content_type = "text/html"

  # Very important for templatefile()
  etag = md5(templatefile("${path.module}/www_site1/index.html.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
  }))
}

resource "aws_s3_object" "php_index" {
  bucket = aws_s3_bucket.static_web_site_bucket.bucket
  key    = "web_site2/index.php"

  content = templatefile("${path.module}/www_site2/index.php.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
    db_host        = aws_db_instance.postgres.address
    db_name        = var.db_name
    db_user        = var.db_user
    db_pass        = var.db_password
  })

  content_type = "application/x-httpd-php"

  etag = md5(templatefile("${path.module}/www_site2/index.php.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
    db_host        = aws_db_instance.postgres.address
    db_name        = var.db_name
    db_user        = var.db_user
    db_pass        = var.db_password
  }))
}


resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "ec2_s3_read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = ["s3:GetObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.static_web_site_bucket.arn,
        "${aws_s3_bucket.static_web_site_bucket.arn}/*"
      ]
    }]
  })
}
/*
resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.static_web_site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_web_site_bucket.arn}/*"
      }
    ]
  })
}
*/
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.static_web_site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontRead",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action   = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.static_web_site_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}


resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac-web-site"
  description                       = "Access control for CloudFront to read S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  comment = "Static web site CDN"

  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.static_web_site_bucket.bucket_regional_domain_name
    origin_id   = "s3-origin"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "postgress-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]

  tags = {
    Name = "db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "test-postgres-db"
  engine                 = "postgres"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  username               = var.db_user
  password               = var.db_password
  db_name                = var.db_name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name

  skip_final_snapshot = true # If you want final snapshot, set to false
}

