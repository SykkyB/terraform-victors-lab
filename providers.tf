terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #version = "~>4.20"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.0.0"
    }
  }
  #required_version = ">= 1.2.8"

  backend "s3" {
    bucket  = "alexrachok-terraform-state-bucket"
    key     = "terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}


provider "sops" {}


provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}