terraform {
    required_providers {
        aws = {
            source  = "hc-registry.website.cloud.croc.ru/c2devel/croccloud"
            version = "4.14.0-CROC4"
        }
    }
}

provider "aws" {
    endpoints {
        ec2 = var.ec2_url
    }

    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_region_validation = true

    access_key = var.access_key
    secret_key = var.secret_key
    region = var.region
}
