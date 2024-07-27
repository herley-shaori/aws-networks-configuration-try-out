provider "aws" {
  region  = "ap-southeast-3"
  profile = "pribadi"
  default_tags {
    tags = {
      project = "bastion-host"
    }
  }
}