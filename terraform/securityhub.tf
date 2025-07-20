module "security_hub" {
  source = "terraform-aws-modules/security-hub/aws"

  enable_security_hub = true
  enable_guardduty    = true
  enable_inspector    = true
  enable_config       = true

  security_hub_standards = [
    "cis-aws-foundations-benchmark",
    "aws-foundational-security-best-practices"
  ]
}