data "aws_iam_policy_document" "terraform_state_bucket_policy" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.terraform.arn]
    }

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]
    resources = ["arn:aws:s3:::my-terraform-state-bucket"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["three-tier-app/*"]
    }
  }

  statement {
    sid    = "ObjectAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.terraform.arn]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]

    resources = ["arn:aws:s3:::my-terraform-state-bucket/three-tier-app/*"]
  }
}

resource "aws_s3_bucket_policy" "terraform_state_bucket" {
  provider = aws.backend
  bucket   = "my-terraform-state-bucket"
  policy   = data.aws_iam_policy_document.terraform_state_bucket_policy.json
}
