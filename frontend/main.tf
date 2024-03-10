terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.26.0"
    }
  }
}

variable "cloudflare_api_token" {
  type = string
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_pages_project" "build_config" {
  account_id = "1e8c347d09a13db3e3d9a9b45bad28ab"
  name = "shark-test"
  production_branch = "master"
  build_config {
    build_command = "npm run build"
    destination_dir = "dist"
    root_dir = "frontend"
  }
  source {
    type = "github"
    config {
      owner = "slack2450"
      repo_name = "shark-test"
      production_branch = "master"
      deployments_enabled = true
      production_deployment_enabled = true
    }
  }  
}

resource "null_resource" "deploy" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "curl -X POST https://api.cloudflare.com/client/v4/pages/webhooks/deploy_hooks/0472fea3-f31e-4e42-8043-7d3d594c3f99"
  }
  
}