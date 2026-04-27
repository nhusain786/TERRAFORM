resource "aws_iam_user" "terraform" {
  name = "terraform"
  path = "/"

  tags = var.tags
}

data "aws_iam_policy_document" "terraform_s3_state_access" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"

    actions = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::my-terraform-state-bucket"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["three-tier-app/*"]
    }
  }

  statement {
    sid    = "BucketReadLocationAndMultipart"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]
    resources = ["arn:aws:s3:::my-terraform-state-bucket"]
  }

  statement {
    sid    = "ObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]

    resources = ["arn:aws:s3:::my-terraform-state-bucket/three-tier-app/*"]
  }
}

resource "aws_iam_user_policy" "terraform_s3_state_access" {
  name   = "terraform-s3-state-access"
  user   = aws_iam_user.terraform.name
  policy = data.aws_iam_policy_document.terraform_s3_state_access.json
}

resource "aws_iam_access_key" "terraform" {
  user = aws_iam_user.terraform.name
}
