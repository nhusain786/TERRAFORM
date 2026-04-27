terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "three-tier-app/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    use_lockfile   = true
  }
}
