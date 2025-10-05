terraform {
  backend "s3" {
    bucket       = "insizon-terraform-remote-state-backend-bucket"
    key          = "do.tfstate"
    region       = "us-east-2"
    profile      = "insizon"
    use_lockfile = true
  }
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}
provider "digitalocean" {
  token = var.do_token
}
