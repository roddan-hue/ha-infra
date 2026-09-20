terraform {
  cloud {
    organization = "bossrod"

    workspaces {
      project = "HA Terraform"
      name    = "ha-aws"
    }
  }

  required_version = ">= 1.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
