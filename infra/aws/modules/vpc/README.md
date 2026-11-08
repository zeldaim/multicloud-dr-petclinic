# VPC Module

고가용성(HA)을 위한 2-Tier Architecture with Zonal Isolation을 제공하는 VPC 모듈입니다.

## Features

- VPC with DNS support
- Internet Gateway
- Public Subnets (2개 - 각 AZ별)
- App Private Subnets (2개 - 각 AZ별)
- DB Private Subnets (2개 - 각 AZ별)
- NAT Gateways (HA - 각 AZ별)
- Route Tables with Zonal Isolation

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr                  = "10.0.0.0/16"
  availability_zones        = ["ap-northeast-2a", "ap-northeast-2b"]
  public_subnet_cidrs       = ["10.0.0.0/25", "10.0.10.0/25"]
  app_private_subnet_cidrs  = ["10.0.0.128/25", "10.0.10.128/25"]
  db_private_subnet_cidrs   = ["10.0.1.0/25", "10.0.11.0/25"]
  eks_cluster_name          = "petclinic-cluster"
  name_prefix               = "petclinic-prod"

  # Tags
  vpc_tags                  = local.vpc_tags
  public_subnet_tags        = local.public_subnet_tags
  app_private_subnet_tags   = local.app_private_subnet_tags
  db_private_subnet_tags    = local.db_private_subnet_tags
}
```

## Outputs

- `vpc_id`: VPC ID
- `public_subnet_ids`: Public Subnet IDs
- `app_private_subnet_ids`: App Private Subnet IDs
- `db_private_subnet_ids`: DB Private Subnet IDs
- `nat_gateway_ids`: NAT Gateway IDs

