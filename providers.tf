terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #version = "~>4.20"
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

provider "aws" {
  region = "us-east-2"
}
