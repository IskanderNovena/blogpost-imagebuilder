# Create the S3 bucket
resource "aws_s3_bucket" "this" {
  bucket        = join("-", [var.name, "image-export-bucket", data.aws_caller_identity.account.account_id])
  force_destroy = true
}

# Set the public access block for the S3 bucket
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Set the Ownership Controls for the S3 bucket
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket.this
  ]
}

# Set the encryption configuration for the S3 bucket and enable the Bucket Key
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
