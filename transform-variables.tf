# =============================================================================
# Reshaping input variables for for_each
# -----------------------------------------------------------------------------
# for_each needs a map (or set) with stable, unique keys. Humans like to write
# nested, readable variables. The locals below bridge that gap: take a friendly
# nested variable and flatten it into the flat maps that resources consume.
# =============================================================================

# A human-friendly nested input: VPCs, each with a list of subnets.
variable "vpcs" {
  description = "Map of VPCs, each with a list of subnets to create."
  type = map(object({
    cidr_block = string
    enabled    = optional(bool, true)
    subnets = list(object({
      name = string
      cidr = string
      az   = string
      # per-subnet override; falls back to the default below when unset
      public = optional(bool)
    }))
  }))
  default = {}

  validation {
    # Every VPC's parent cidr_block must be valid CIDR notation.
    condition = alltrue([
      for vpc in var.vpcs : can(cidrhost(vpc.cidr_block, 0))
    ])
    error_message = "Each VPC cidr_block must be valid CIDR notation, e.g. 10.0.0.0/16."
  }
}

# A default to merge into every subnet when the user omits a field.
variable "subnet_defaults" {
  description = "Defaults applied to each subnet unless overridden."
  type = object({
    public = bool
  })
  default = {
    public = false
  }
}

locals {
  # ---------------------------------------------------------------------------
  # 1. Filter: keep only enabled VPCs.
  #    A `for` with an `if` drops elements that don't match.
  # ---------------------------------------------------------------------------
  enabled_vpcs = {
    for name, vpc in var.vpcs : name => vpc if vpc.enabled
  }

  # ---------------------------------------------------------------------------
  # 2. Flatten: turn map(vpc -> list(subnet)) into a flat LIST of objects,
  #    carrying the parent key down into each child so nothing is lost.
  #    flatten() collapses the nested lists into one.
  # ---------------------------------------------------------------------------
  subnets_flat = flatten([
    for vpc_name, vpc in local.enabled_vpcs : [
      for subnet in vpc.subnets : {
        vpc_name = vpc_name
        vpc_cidr = vpc.cidr_block
        name     = subnet.name
        cidr     = subnet.cidr
        az       = subnet.az
        # 3. Merge defaults: use the override if set, else the default.
        public = coalesce(subnet.public, var.subnet_defaults.public)
      }
    ]
  ])

  # ---------------------------------------------------------------------------
  # 4. Project to a map with a unique, STABLE composite key.
  #    for_each requires a map; the key must not depend on list order
  #    (indexes shift when you add/remove elements and churn resources).
  # ---------------------------------------------------------------------------
  subnets_by_key = {
    for s in local.subnets_flat : "${s.vpc_name}/${s.name}" => s
  }

  # ---------------------------------------------------------------------------
  # Bonus: list -> map projection. for_each can't take a list of objects,
  # so project a plain list into a keyed map first.
  # ---------------------------------------------------------------------------
  # Given var.list = [{ name = "a", ... }, { name = "b", ... }]:
  #   list_as_map = { for item in var.list : item.name => item }
}

# -----------------------------------------------------------------------------
# How you'd consume the reshaped locals (uncomment and adapt):
# -----------------------------------------------------------------------------
# resource "aws_subnet" "this" {
#   for_each          = local.subnets_by_key
#   vpc_id            = aws_vpc.this[each.value.vpc_name].id
#   cidr_block        = each.value.cidr
#   availability_zone = each.value.az
#   map_public_ip_on_launch = each.value.public
#   tags = { Name = each.value.name }
# }
#
# Reference a single one by its composite key:
#   aws_subnet.this["vpc1/app-a"].id
