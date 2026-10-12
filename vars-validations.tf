# Validate a variable has a minimum of N chars
variable "env" {
  type        = string
  description = "Environment (DEV, QA, PROD, etc.)"
  validation {
    condition     = length(var.env) > 1
    error_message = "Enter an environment name equal or longer than 2 chars."
  }
}

# Validate a region belongs to a finite list
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Select one of the following: us-east-1, us-east-2, us-west-1, us-west-2"
  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-1", "us-west-2"], var.region)
    error_message = "Error: The region is incorrect."
  }
}

############## ARNs ####################
# KMS ARN
variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key"
  default     = "arn:aws:kms:<REGION_ID>:<ACCOUNT_ID>:key/<KMS_ID>"

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z][a-z]-[a-z]+-[1-9]:[[:digit:]]{12}:key/.+", var.kms_key_arn))
    error_message = format("The KMS key ARN (%s) is invalid.", var.kms_key_arn)
  }
}

# CloudWatch Log Group ARN
variable "cloudwatch_loggroup_arn" {
  type        = string
  description = "ARN of the CloudWatch Log Group."

  validation {
    condition     = can(regex("^arn:aws:logs:[a-z][a-z]-[a-z]+-[1-9]:[[:digit:]]{12}:log-group:/.+", var.cloudwatch_loggroup_arn))
    error_message = format("The Log Group ARN (%s) is invalid.", var.cloudwatch_loggroup_arn)
  }
}

# S3 ARN
variable "logs_bucket_arn" {
  type        = string
  description = "ARN of the bucket where that will be used for logging."

  validation {
    condition     = can(regex("^arn:aws:s3:::*", var.logs_bucket_arn))
    error_message = format("The ARN for the S3 Bucket logs_bucket_arn (%s) is invalid.", var.logs_bucket_arn)
  }
}

# RAM ARN
variable "share_arn" {
  description = "RAM Share ARN for resolver rules"
  type        = string

  validation {
    # condition     = length(var.org_arn) == 48 && substr(var.org_arn, 0, 23) == "arn:aws:organizations::"
    condition     = can(regex("^arn:aws:ram:[a-z][a-z]-[a-z]+-[1-9]:[[:digit:]]{12}:resource-share/.+", var.share_arn))
    error_message = format("The Resource Share ARN (%s) is invalid.", var.share_arn)
  }
}

# IAM Role ARN
variable "my_iam_role_arn" {
  type        = string
  description = "ARN of the role that will be assume by Resource X."

  validation {
    condition     = can(regex("^arn:aws:iam::[[:digit:]]{12}:role/.+", var.my_iam_role_arn))
    error_message = format("The IAM role ARN for my_iam_role_arn (%s) is invalid.", var.my_iam_role_arn)
  }
}


############# IDs: VPC, Subnet, Security Group ###############
variable "vpc_id" {
  type = string

  validation {
    condition     = length(var.vpc_id) == 21 && substr(var.vpc_id, 0, 4) == "vpc-"
    error_message = format("The VPC ID (%s) is invalid, it should start with \"vpc-\" and have a length of 21 characters (length is %s).", var.vpc_id, length(var.vpc_id))
  }
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet where the DataSync Agent(s) will be created."

  validation {
    condition     = length(var.subnet_id) == 24 && substr(var.subnet_id, 0, 7) == "subnet-"
    error_message = format("The Subnet ID (%s) is invalid, it should start with \"subnet-\" and have a length of 24 characters (length is %s).", var.subnet_id, length(var.subnet_id))
  }
}

variable "vpc_endpoint_id" {
  type        = string
  description = "VPC endpoint ID."

  validation {
    condition     = can(regex("^vpce-.+", var.vpc_endpoint_id))
    error_message = format("The VPC Endpoint ID (%s) is invalid.", var.vpc_endpoint_id)
  }
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID with rules to ports 80, 443, 22 and 1024-1064 that will be used by the EC2 instances."
  validation {
    condition     = can(regex("^sg-.+", var.security_group_id))
    error_message = format("The Security Group ID (%s) is invalid.", var.security_group_id)
  }
}



############# LISTS ###################
# List has at least 1 value
variable "sources_list" {
  type        = map(any)
  description = "List of objects where each element is a source to create."
  validation {
    condition     = length(var.sources_list) > 0
    error_message = "Provide at least 1 element to the list of Sources to create."
  }
}

# Value given belongs to a finite list of possible options
variable "datasync_tasks_report_level" {
  type        = string
  description = "Optional. Report level for the DataSync Tasks reports. Options are ERRORS_ONLY or SUCCESSES_AND_ERRORS. If no value is given, it defaults to SUCCESSES_AND_ERRORS."
  default     = "SUCCESSES_AND_ERRORS"

  validation {
    condition     = contains(["ERRORS_ONLY", "SUCCESSES_AND_ERRORS"], var.datasync_tasks_report_level)
    error_message = "Valid values for var: datasync_tasks_report_level are ERRORS_ONLY or SUCCESSES_AND_ERRORS."
  }
}

variable "archive_storage_class" {
  type        = string
  description = "Storage class to use for archival of files."
  default     = "DEEP_ARCHIVE"

  validation {
    condition     = can(regex("^(STANDARD|STANDARD_IA|GLACIER|DEEP_ARCHIVE)$", var.archive_storage_class))
    error_message = format("Invalid input for archive_storage_class, options are: \"STANDARD\", \"STANDARD_IA\", \"GLACIER\", \"DEEP_ARCHIVE\" (value given: %s).", var.archive_storage_class)
  }
}
