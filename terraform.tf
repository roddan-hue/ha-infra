terraform {
    cloud{

        workspaces {
            project = "HA Terraform"
            name = "ha-aws"
        }
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 6.57"
        }
    }
    required_version = ">= 1.2"
}