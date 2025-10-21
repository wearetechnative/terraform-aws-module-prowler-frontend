provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = ["489947827123"]

  assume_role {
    role_arn     = "arn:aws:iam::489947827123:role/landing_zone_devops_administrator"
    session_name = "terraform_management_account"
  }

  default_tags {
    tags = {
      Company     = "TechnativeBV"
      IaC_Project = "jeroentje"
      IaC_backend = "default"
    }
  }
}

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 4.0.0"
    }
  }
}

provider "aws" {

  alias               = "us-east-1"
  region              = "us-east-1"
  allowed_account_ids = ["489947827123"]

  assume_role {
    role_arn     = "arn:aws:iam::489947827123:role/landing_zone_devops_administrator"
    session_name = "terraform_management_account"
  }

  default_tags {
    tags = {
      Company     = "TechnativeBV"
      IaC_Project = "jeroentje"
      IaC_backend = "default"
    }
  }
}