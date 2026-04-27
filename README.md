# TERRAFORM

This repository contains Terraform configuration for deploying a three-tier AWS application topology.

## Included files

- `backend.tf` - Terraform remote state backend configuration
- `provider.tf` - AWS provider configuration
- `main.tf` - VPC, networking, ALB, autoscaling groups, and database resources
- `iam_user.tf` - Terraform IAM user and access policy
- `s3_bucket_policy.tf` - S3 bucket policy for Terraform state access
- `variables.tf` - Variable definitions and defaults
- `outputs.tf` - Useful output values after deployment

## Notes

- Update `aws_access_key`, `aws_secret_key`, and `db_password` via Terraform variables or a secure `*.tfvars` file.
- Do not check in sensitive values to source control.

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```
2. Review the execution plan:
   ```bash
   terraform plan
   ```
3. Apply the changes:
   ```bash
   terraform apply
   ```

## License

No license specified.
