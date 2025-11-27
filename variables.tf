############################################################
# VARIABLES
############################################################

# ---------------- EC2 / Bastion ----------------
variable "instance_ami" {
  description = "AMI for EC2 instance"
  type        = string
  default     = "ami-097a2df4ac947655f"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "SSH key name"
  type        = string
  default     = "aws_key"
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8bJfR85v9E+M096iS8Tn5eqOD3BpjezKfbASwNA8Um azuread\\aliaksandrrachok@EPGETBIW0398"
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access NLB"
  type        = string
  default     = "31.146.15.0/24"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

# ---------------- Database ----------------
variable "db_user" {
  description = "Postgres DB username"
  type        = string
  sensitive   = true
  default     = "postgres_admin"
}

variable "db_password" {
  description = "Postgres DB password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Postgres DB name"
  type        = string
  default     = "postgres"
}

variable "exchange_updater_container_image" {
  description = "ECR image URI for exchange updater"
  type        = string
  default     = "815408489721.dkr.ecr.us-east-2.amazonaws.com/exchange-updater:latest"
}