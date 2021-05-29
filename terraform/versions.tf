
terraform {
  required_version = ">= 0.12"
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  backend "s3" {
    bucket = "alam0rt-tfstate"
    key    = "kloud/banshee"
    region = "ap-southeast-2"
  }
}
