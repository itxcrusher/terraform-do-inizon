terraform {
  backend "s3" {} # rendered at runtime by shell/common.sh -> backend.hcl
  required_providers {
    digitalocean = { source = "digitalocean/digitalocean" }
    aws          = { source = "hashicorp/aws" }
  }
}
provider "digitalocean" {
  token = var.do_token
}
provider "aws" {}
