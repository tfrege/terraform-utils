# =============================================================================
# Environment / account context data sources
# Each data source below pulls information about the environment Terraform is
# running against. The accompanying local in locals.tf-style blocks shows a
# practical way to consume the value.
# =============================================================================

# Current AWS Account ID
data "aws_caller_identity" "current" {}
# Reference as: data.aws_caller_identity.current.account_id

# Current partition (aws, aws-us-gov, aws-cn)
data "aws_partition" "current" {}
# Reference as: data.aws_partition.current.partition

# Current region
data "aws_region" "current" {}
# Reference as: data.aws_region.current.name

# Availability zones available to this account in the current region
data "aws_availability_zones" "available" {
  state = "available"
}
# Reference as: data.aws_availability_zones.available.names

# All regions enabled for this account
data "aws_regions" "current" {}
# Reference as: data.aws_regions.current.names

# The DNS suffix for the current partition (e.g. amazonaws.com, amazonaws.com.cn)
data "aws_partition" "dns" {}
# Reference as: data.aws_partition.dns.dns_suffix

# Service principal for a given service in this partition/region.
# Useful for building IAM trust policies that work across partitions.
data "aws_service_principal" "ec2" {
  service_name = "ec2"
}
# Reference as: data.aws_service_principal.ec2.name

# The default EC2 platform / default VPC for the region
data "aws_vpc" "default" {
  default = true
}
# Reference as: data.aws_vpc.default.id

# The newest Amazon Linux 2023 AMI owned by Amazon in this region
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
# Reference as: data.aws_ami.al2023.id

# IAM account alias (if one is set on the account)
data "aws_iam_account_alias" "current" {}
# Reference as: data.aws_iam_account_alias.current.account_alias

# The ARN of the identity Terraform is currently running as
# (same data source as account_id, different attribute)
# Reference as: data.aws_caller_identity.current.arn

# =============================================================================
# Example locals: how to use each data source above
# =============================================================================

locals {
  # --- Core identity ------------------------------------------------------
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
  caller_arn = data.aws_caller_identity.current.arn
  dns_suffix = data.aws_partition.dns.dns_suffix

  # Detect which partition we are in so modules can branch on GovCloud/China.
  is_govcloud = data.aws_partition.current.partition == "aws-us-gov"
  is_china    = data.aws_partition.current.partition == "aws-cn"

  # --- Availability zones -------------------------------------------------
  azs = data.aws_availability_zones.available.names

  # Take the first three AZs for a typical multi-AZ layout.
  azs_three = slice(data.aws_availability_zones.available.names, 0, 3)

  # Build a map of az -> index, handy for assigning subnet CIDRs.
  az_index = {
    for idx, az in data.aws_availability_zones.available.names : az => idx
  }

  # --- Regions ------------------------------------------------------------
  enabled_regions   = data.aws_regions.current.names
  region_is_enabled = contains(data.aws_regions.current.names, data.aws_region.current.name)

  # --- Partition-aware ARNs -----------------------------------------------
  # Build an S3 bucket ARN that is correct in any partition.
  logging_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::my-logs-${data.aws_caller_identity.current.account_id}"

  # Build the account root ARN for IAM policies.
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"

  # Partition-correct EC2 service principal for an assume-role trust policy.
  ec2_service_principal = data.aws_service_principal.ec2.name

  # --- Networking ---------------------------------------------------------
  default_vpc_id   = data.aws_vpc.default.id
  default_vpc_cidr = data.aws_vpc.default.cidr_block

  # --- AMI ----------------------------------------------------------------
  al2023_ami_id = data.aws_ami.al2023.id

  # --- Account alias ------------------------------------------------------
  account_alias = data.aws_iam_account_alias.current.account_alias

  # --- Common tags built from environment data ----------------------------
  # A single tag map you can merge into every resource's tags.
  common_tags = {
    AccountId = data.aws_caller_identity.current.account_id
    Region    = data.aws_region.current.name
    Partition = data.aws_partition.current.partition
    ManagedBy = "terraform"
  }
}
