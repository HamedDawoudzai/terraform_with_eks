terraform {
  backend "s3" {
    bucket         = "hameds-eks-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hameds-eks-terraform-locks"
    encrypt        = true
  }
}
