data "aws_caller_identity" "current" {}

resource "aws_securityhub_account" "main" {}

#resource "aws_securityhub_standards_subscription" "cis" {
#  depends_on    = [aws_securityhub_account.main]
#  standards_arn = "arn:aws:securityhub:eu-central-1:071844616048:standards/cis-aws-foundations-benchmark/v/1.2.0"
#}

resource "aws_securityhub_standards_subscription" "aws_best_practices" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:eu-central-1::standards/aws-foundational-security-best-practices/v/1.0.0"
}


resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_inspector2_enabler" "main" {
  account_ids = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2", "ECR", "LAMBDA"]
}

resource "aws_iam_role" "config" {
  name = "aws-config-recorder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "aws-configs"
  role_arn = aws_iam_role.config.arn
}

resource "aws_s3_bucket" "config_bucket" {
  bucket = "aft-config-delivery-${data.aws_caller_identity.current.account_id}-eu-central-1"
  force_destroy = true

  tags = {
    Name        = "AFT Config Delivery Bucket"
    Environment = "AFT"
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AWSConfigFullAccessPut",
        Effect: "Allow",
        Principal: {
          Service: "config.amazonaws.com"
        },
        Action: [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObjectAcl"
        ],
        Resource: [
          "arn:aws:s3:::${aws_s3_bucket.config_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/*"
        ],
        Condition: {
          StringEquals: {
            "s3:x-amz-acl": "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}




resource "aws_config_delivery_channel" "main" {
  name           = "channel-delivery"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
  s3_key_prefix  = "${data.aws_caller_identity.current.account_id}/Config"
  depends_on     = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name    = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}
