terraform {
  backend "s3" {
    bucket  = "berkeley-samia-tf-state"
    key     = "eks/terraform.tfstate"
    region  = "ap-southeast-2"
    encrypt = true
  }
}
