terraform {
  backend "s3" {
    bucket         = "cdk-eks-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "eks-cluster-lock"
    encrypt        = true
  }
}