# Create a KMS key for encrypting the SNS topic
resource "aws_kms_key" "sns_key" {
  description             = "Encryption Key For SNS topic: imagebuilder-${var.name}-notifications"
  deletion_window_in_days = 30
  is_enabled              = true
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        "Principal" : {
          AWS = "arn:aws:iam::${data.aws_caller_identity.account.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Effect = "Allow"
        "Principal" : {
          Service = "imagebuilder.amazonaws.com"
        },
        "Action" : [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
        ],
        Resource = "*"
      }
    ]
  })
}

# Create an alias for the KMS key
resource "aws_kms_alias" "sns_key_alias" {
  name          = join("-", ["alias/sns-kms-key-imagebuilder", var.name])
  target_key_id = aws_kms_key.sns_key.key_id
}

# Create the SNS topic
resource "aws_sns_topic" "this" {
  name              = "imagebuilder-${var.name}-notifications"
  kms_master_key_id = aws_kms_key.sns_key.key_id
}

# Add the SNS topic policy
resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn = aws_sns_topic.this.arn

  policy = jsonencode({
    Version = "2012-10-17"
    "Statement" : [
      {
        Sid    = "0",
        Effect = "Allow"
        "Principal" : {
          Service = "imagebuilder.amazonaws.com"
        },
        Action = [
          "sns:Publish",
        ]
        Resource = "*"
      }
    ]
  })
}
