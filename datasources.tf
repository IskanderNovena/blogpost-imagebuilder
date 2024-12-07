data "aws_caller_identity" "account" {}
data "aws_region" "current" {}
data "aws_canonical_user_id" "current" {}
data "aws_ebs_encryption_by_default" "current" {
  lifecycle {
    # If EBS Encryption By Default is enabled, we can't create an AMI that can be exported
    postcondition {
      condition     = self.enabled == false
      error_message = "EBS Encryption by Default must be disabled to be able to export an AMI-image."
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
