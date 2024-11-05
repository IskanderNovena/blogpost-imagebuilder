# Create the Image Builder Build role
resource "aws_iam_role" "imagebuilder_build" {
  name = join("-", ["Ec2ImageBuilderBuildRole", var.name])

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Principal = {
            Service = "ec2.amazonaws.com"
          },
          Action = "sts:AssumeRole"
        }
      ]
    }
  )
}

# Add managed policies to the Image Builder Build role
resource "aws_iam_role_policy_attachments_exclusive" "imagebuilder_build" {
  role_name = aws_iam_role.imagebuilder_build.name
  policy_arns = [
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}

# Add inline policy to the Image Builder Build role
resource "aws_iam_role_policy" "imagebuilder_build_policy" {
  name = "ImageBuilderBuildPolicy"
  role = aws_iam_role.imagebuilder_build.id

  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Sid    = "AllowVolumeModifications",
          Effect = "Allow",
          Action = [
            "ec2:DescribeInstances",
            "ec2:ModifyVolume",
            "ec2:DescribeVolumeStatus",
            "ec2:DescribeVolumesModifications",
            "ec2:DescribeVolumes"
          ],
          Resource = "*"
        }
      ]
  })
}

# Manage all inline policies for the Image Builder Build role through Terraform
resource "aws_iam_role_policies_exclusive" "imagebuilder_build_inline_policies" {
  role_name    = aws_iam_role.imagebuilder_build.name
  policy_names = [aws_iam_role_policy.imagebuilder_build_policy.name]
}

# Create an instance profile from the Image Builder Build role
resource "aws_iam_instance_profile" "imagebuilder_build" {
  name = aws_iam_role.imagebuilder_build.name
  role = aws_iam_role.imagebuilder_build.name
}

# Create the Image Builder Lifecycle Management role
resource "aws_iam_role" "imagebuilder_lifecycle_management" {
  name = join("-", ["ImageBuilderLifeCycleManagementRole", var.name])

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Principal = {
            Service = "imagebuilder.amazonaws.com"
          },
          Action = "sts:AssumeRole"
        }
      ]
    }
  )
}

# Add managed policies to the Image Builder Lifecycle Management role
resource "aws_iam_role_policy_attachments_exclusive" "imagebuilder_lifecycle_management" {
  role_name = aws_iam_role.imagebuilder_lifecycle_management.name
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/EC2ImageBuilderLifecycleExecutionPolicy",
  ]
}

# Create the Image Builder Export role
resource "aws_iam_role" "vmexport" {
  name = join("-", ["imagebuilder-vmexport", var.name])

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vmie.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Add inline policy to the Image Builder Export role
resource "aws_iam_role_policy" "vmexport_policy" {
  name = "vmexport"
  role = aws_iam_role.vmexport.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetBucketAcl",
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.this.id}",
          "arn:aws:s3:::${aws_s3_bucket.this.id}/*",
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ],
        Resource = "*"
      }
    ]
  })
}

# Manage all inline policies for the Image Builder Export role through Terraform
resource "aws_iam_role_policies_exclusive" "imagebuilder_lcm_inline_policies" {
  role_name    = aws_iam_role.vmexport.name
  policy_names = [aws_iam_role_policy.vmexport_policy.name]
}
