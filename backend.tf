
terraform {
  backend "s3" {
    bucket = "rabolf-terraform-state-bucket"
    key    = "state/terraform_state.tfstate"
    region = "us-east-1"
  }
}