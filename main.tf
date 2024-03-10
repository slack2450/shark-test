terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.40.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.26.0"
    }
  }

  cloud {
    organization = "shark-test"

    workspaces {
      name = "shark-test"
    }
  }
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

provider "aws" {
  region = "eu-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "aws" {
  alias      = "us_east_1"
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "api" {
  source = "./backend"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  cloudflare_api_token = var.cloudflare_api_token
}

module "frontend" {
  source = "./frontend"
  cloudflare_api_token = var.cloudflare_api_token
}