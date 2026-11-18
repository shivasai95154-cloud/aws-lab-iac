# Run this ONCE (from CloudShell). It creates what GitHub Actions needs before it can run:
#  - an S3 bucket to store Terraform state
#  - a GitHub -> AWS trust (OIDC) and an IAM role that only YOUR repo can use
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "region" { default = "ap-south-1" }
variable "github_repo" {
  description = "owner/repo, e.g. ramesh/aws-lab-iac"
  type        = string
}
variable "create_oidc_provider" {
  description = "Set false if your AWS account already has the GitHub OIDC provider"
  type        = bool
  default     = true
}

provider "aws" { region = var.region }
data "aws_caller_identity" "me" {}

resource "aws_s3_bucket" "state" {
  bucket = "tfstate-${data.aws_caller_identity.me.account_id}-${var.region}"
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}
locals {
  oidc_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github" {
  name = "github-actions-terraform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.oidc_arn }
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" }
      }
    }]
  })
}
# Lab only: full access so Terraform can create VPC, EC2, ALB, IAM. Tighten for real projects.
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "AWS_ROLE_ARN" { value = aws_iam_role.github.arn }
output "TF_STATE_BUCKET" { value = aws_s3_bucket.state.bucket }
output "AWS_REGION" { value = var.region }
