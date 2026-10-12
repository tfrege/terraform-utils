# =============================================================================
# Carving a VPC CIDR into subnets
# -----------------------------------------------------------------------------
# cidrsubnet() / cidrsubnets() split a parent CIDR into smaller blocks without
# hardcoding addresses. Pairs with the az_index / azs_three locals in
# get-environmental-data.tf for a clean per-AZ layout.
# =============================================================================

variable "vpc_cidr" {
  description = "Parent CIDR block the subnets are carved out of."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    # Must be valid CIDR notation. cidrhost() errors on a bad value;
    # can() turns that error into false so the message is clean.
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be valid CIDR notation, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "az_count must be between 1 and 6."
  }
}

locals {
  # ---------------------------------------------------------------------------
  # Approach A: cidrsubnet() with a loop. Add `newbits` to the prefix and pick
  # the Nth block. /16 + 8 newbits = /24; netnum 0..az_count-1 picks each one.
  #   10.0.0.0/16 -> 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24, ...
  # ---------------------------------------------------------------------------
  private_subnet_cidrs = [
    for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)
  ]

  # Public subnets placed in a higher range so they never overlap the private
  # ones (offset the netnum by az_count).
  public_subnet_cidrs = [
    for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + var.az_count)
  ]

  # ---------------------------------------------------------------------------
  # Approach B: cidrsubnets() computes several blocks of mixed sizes in one
  # call. Each argument is the newbits for that block, allocated in order.
  #   two /24s (public) then two /20s (private), all from the parent /16.
  # ---------------------------------------------------------------------------
  mixed_blocks = cidrsubnets(var.vpc_cidr, 8, 8, 4, 4)
  # mixed_blocks[0], [1] are /24; [2], [3] are /20.

  # ---------------------------------------------------------------------------
  # Zip AZs to CIDRs into a for_each-ready map. Combine with
  # data.aws_availability_zones.available.names from get-environmental-data.tf.
  # ---------------------------------------------------------------------------
  # subnets_by_az = {
  #   for i in range(var.az_count) :
  #   data.aws_availability_zones.available.names[i] => local.private_subnet_cidrs[i]
  # }
}

# -----------------------------------------------------------------------------
# Usage (uncomment and adapt):
# -----------------------------------------------------------------------------
# resource "aws_subnet" "private" {
#   for_each          = local.subnets_by_az
#   vpc_id            = aws_vpc.this.id
#   availability_zone = each.key
#   cidr_block        = each.value
# }
