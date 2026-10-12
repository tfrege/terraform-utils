# =============================================================================
# Tagging patterns
# -----------------------------------------------------------------------------
# Two layers that work together:
#   1. provider `default_tags` — applied automatically to every taggable
#      resource, so you never hand-tag the basics.
#   2. a merge() local — for per-resource tags layered on top of the defaults.
# =============================================================================

variable "environment" {
  description = "Deployment environment, used as a tag on every resource."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, stage, prod."
  }
}

variable "cost_center" {
  description = "Cost center / billing code applied as a tag to every resource."
  type        = string
  default     = "unassigned"

  validation {
    condition     = length(var.cost_center) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "extra_tags" {
  description = "Optional additional tags to merge into the default tag set."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Provider-level default tags: every taggable resource created by this provider
# inherits these without any per-resource code. Uncomment to use.
# -----------------------------------------------------------------------------
# provider "aws" {
#   default_tags {
#     tags = local.default_tags
#   }
# }

locals {
  # The baseline tag set. Keep this to things that apply to EVERYTHING.
  default_tags = merge(
    {
      Environment = var.environment
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
    },
    var.extra_tags,
  )

  # Per-resource tagging: start from the defaults, add resource-specific keys.
  # Use this when a resource needs tags beyond the provider defaults, or when
  # the resource type doesn't honor provider default_tags.
  #
  # Example:
  #   tags = merge(local.default_tags, { Name = "app-bucket", Tier = "data" })
}

# -----------------------------------------------------------------------------
# Usage without provider default_tags (explicit per-resource):
# -----------------------------------------------------------------------------
# resource "aws_s3_bucket" "example" {
#   bucket = "my-bucket"
#   tags   = merge(local.default_tags, { Name = "my-bucket" })
# }
