# terraform-validations

A small toolbox of copy-paste Terraform snippets I reach for again and again when building AWS modules: ready-made input **validation rules**, a cheat sheet of **environment data sources**, and the **locals patterns** developers re-derive on every module. Grab what you need, drop it into your module, tweak, done.

## What's inside

| File                                                       | What you get                                                                                                                                                              |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`vars-validations.tf`](./vars-validations.tf)             | `variable` blocks with built-in `validation {}` rules — reject bad regions, malformed ARNs, wrong-shaped resource IDs, and empty lists at plan time instead of mid-apply. |
| [`get-environmental-data.tf`](./get-environmental-data.tf) | Common AWS data sources (account ID, partition, region, AZs, default VPC, latest AL2023 AMI) plus a `locals` block showing how to use each one.                           |
| [`transform-variables.tf`](./transform-variables.tf)       | `locals` that reshape a nested, friendly input variable into the flat `for_each`-ready maps resources consume — flatten, filter, merge defaults, stable composite keys.   |
| [`tags.tf`](./tags.tf)                                     | Two-layer tagging: a provider `default_tags` set plus a `merge()` local for per-resource tags on top of it.                                                               |
| [`cidr-subnets.tf`](./cidr-subnets.tf)                     | `cidrsubnet()` / `cidrsubnets()` patterns that carve a VPC CIDR into per-AZ subnet blocks without hardcoding addresses.                                                   |

## Why bother

Catching a bad input at `terraform plan` with a clear message beats watching `apply` blow up against the AWS API ten minutes in. The validation snippets fail fast and tell the user exactly what was wrong:

```hcl
terraform plan -var 'region=eu-west-1'
# Error: The region is incorrect.
```

The data-source snippets save you from re-remembering attribute names and let you write partition-aware ARNs that work in commercial, GovCloud, and China:

```hcl
account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
```

## Validation catalog (`vars-validations.tf`)

| Variable                      | Pattern              | Rule                                                      |
| ----------------------------- | -------------------- | --------------------------------------------------------- |
| `env`                         | Minimum length       | At least 2 characters                                     |
| `region`                      | Allowed values       | One of `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2` |
| `kms_key_arn`                 | ARN format           | Matches a KMS key ARN                                     |
| `cloudwatch_loggroup_arn`     | ARN format           | Matches a CloudWatch Log Group ARN                        |
| `logs_bucket_arn`             | ARN format           | Matches an S3 bucket ARN                                  |
| `share_arn`                   | ARN format           | Matches a RAM resource-share ARN                          |
| `my_iam_role_arn`             | ARN format           | Matches an IAM role ARN                                   |
| `vpc_id`                      | ID format            | Starts with `vpc-`, length 21                             |
| `subnet_id`                   | ID format            | Starts with `subnet-`, length 24                          |
| `vpc_endpoint_id`             | ID format            | Starts with `vpce-`                                       |
| `security_group_id`           | ID format            | Starts with `sg-`                                         |
| `sources_list`                | Non-empty collection | Map must have at least 1 element                          |
| `datasync_tasks_report_level` | Allowed values       | `ERRORS_ONLY` or `SUCCESSES_AND_ERRORS`                   |
| `archive_storage_class`       | Allowed values       | `STANDARD`, `STANDARD_IA`, `GLACIER`, or `DEEP_ARCHIVE`   |

Techniques used: `length()` for size, `contains([...], var.x)` for fixed option sets, `can(regex(...))` for ARN and ID shapes, `substr()` + `length()` for prefix + exact length, and `format(...)` to echo the bad value back in the error message.

## Environment data (`get-environmental-data.tf`)

Data sources for the account and region Terraform is pointed at — `aws_caller_identity`, `aws_partition`, `aws_region`, `aws_availability_zones`, `aws_regions`, `aws_service_principal`, `aws_vpc` (default), `aws_ami` (latest AL2023), and `aws_iam_account_alias`. Each one has an inline `# Reference as:` note, and the `locals` block at the bottom shows practical uses: three-AZ slices, an az-to-index map, partition-aware ARNs, GovCloud/China detection, and a `common_tags` map.

## Reshaping variables for `for_each` (`transform-variables.tf`)

`for_each` needs a map with stable, unique keys, but humans write nested, readable variables. This file walks a nested `vpcs` input (VPCs each holding a list of subnets) through the full reshape: **filter** out disabled entries, **flatten** the nested lists into one list of objects (carrying the parent key down), **merge** per-element defaults, and **project** to a map keyed by a stable composite key like `"vpc1/app-a"` so adding or removing elements never churns unrelated resources. Also shows the list-to-map projection `for_each` requires.

## Tagging (`tags.tf`)

Two layers that stack: a provider `default_tags` block so every taggable resource inherits `Environment`, `CostCenter`, and `ManagedBy` automatically, plus a `merge(local.default_tags, {...})` local for layering per-resource tags on top. Use the merge form for resources that need extra keys or don't honor provider defaults.

## CIDR math (`cidr-subnets.tf`)

Carve a parent VPC CIDR into subnets without hardcoding addresses. Shows `cidrsubnet()` in a loop for uniform per-AZ `/24`s (private and non-overlapping public ranges), `cidrsubnets()` for several mixed-size blocks in one call, and how to zip AZs to CIDRs into a `for_each`-ready map that pairs with the AZ data source in `get-environmental-data.tf`.

## How to use

1. Open the file you need.
2. Copy the `variable` or `data` blocks into your module.
3. Adjust types, defaults, and rules to match your case.

## Good to know

- ARN regexes assume the commercial partition (`arn:aws:...`). For GovCloud or China, widen the partition segment to `aws-us-gov` / `aws-cn`.
- Rules here reference only their own variable, so they run on any Terraform version. Cross-variable validation (a rule referencing a *different* variable) needs Terraform 1.9+.
