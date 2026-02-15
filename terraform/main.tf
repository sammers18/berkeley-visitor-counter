data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

data "aws_region" "current" {}

###############IAM##################

# Cluster Manager user
module "cluster_manager_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 5.0"

  name          = var.admin_username
  force_destroy = false # PROD: prevent accidental deletion of IAM user

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}

# Cluster Manager policy - least privilege
module "cluster_manager_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.0"

  name        = "${var.cluster_name}-cluster-manager-policy"
  description = "Least privilege permissions for EKS, VPC, ElastiCache management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ── EKS: scoped to this cluster ──
      {
        Sid    = "EKSClusterManagement"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:DescribeUpdate",
          "eks:ListClusters",
          "eks:ListUpdates",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:ListTagsForResource",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "eks:ListAssociatedAccessPolicies",
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:DescribeAccessEntry",
          "eks:ListAccessEntries",
          "eks:AssociateEncryptionConfig"
        ]
        Resource = "arn:aws:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}"
      },
      {
        Sid    = "EKSNodeGroupManagement"
        Effect = "Allow"
        Action = [
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:TagResource"
        ]
        Resource = [
          "arn:aws:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}",
          "arn:aws:eks:${local.region}:${local.account_id}:nodegroup/${var.cluster_name}/*/*"
        ]
      },
      {
        Sid    = "EKSAddonManagement"
        Effect = "Allow"
        Action = [
          "eks:CreateAddon",
          "eks:DeleteAddon",
          "eks:DescribeAddon",
          "eks:DescribeAddonVersions",
          "eks:ListAddons",
          "eks:UpdateAddon"
        ]
        Resource = "arn:aws:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}"
      },
      # ── VPC: explicit actions with tag condition ──
      {
        Sid    = "VPCManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:DescribeVpcs", "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:DescribeAddresses",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:DescribeRouteTables",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroups", "ec2:DescribeSecurityGroupRules",
          "ec2:CreateNetworkAclEntry", "ec2:DeleteNetworkAclEntry",
          "ec2:DescribeNetworkAcls",
          "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAccountAttributes",
          "ec2:CreateLaunchTemplate", "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate", "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:RunInstances",
          "ec2:DescribeInstances", "ec2:DescribeInstanceTypes",
          "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs",
          "ec2:DescribeFlowLogs"
        ]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "aws:ResourceTag/Project" = "berkeley-visitor-counter"
          }
        }
      },
      # ── ElastiCache: scoped by project tag ──
      {
        Sid    = "ElastiCacheManagement"
        Effect = "Allow"
        Action = [
          "elasticache:CreateReplicationGroup",
          "elasticache:DeleteReplicationGroup",
          "elasticache:DescribeReplicationGroups",
          "elasticache:ModifyReplicationGroup",
          "elasticache:CreateCacheSubnetGroup",
          "elasticache:DeleteCacheSubnetGroup",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:ModifyCacheSubnetGroup",
          "elasticache:CreateCacheParameterGroup",
          "elasticache:DeleteCacheParameterGroup",
          "elasticache:DescribeCacheParameterGroups",
          "elasticache:ModifyCacheParameterGroup",
          "elasticache:DescribeCacheParameters",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeEngineDefaultParameters",
          "elasticache:ListTagsForResource",
          "elasticache:AddTagsToResource",
          "elasticache:RemoveTagsFromResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "berkeley-visitor-counter"
          }
        }
      },
      {
        Sid    = "ElastiCacheDescribe"
        Effect = "Allow"
        Action = [
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:DescribeCacheParameterGroups",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeEngineDefaultParameters",
          "elasticache:DescribeCacheParameters"
        ]
        Resource = "*"
      },
      # ── IAM: scoped to project-prefixed roles ──
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:TagRole",
          "iam:UntagRole", "iam:UpdateAssumeRolePolicy",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/${var.cluster_name}-*"
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::${local.account_id}:role/${var.cluster_name}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "eks.amazonaws.com",
              "ec2.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "IAMPolicyManagement"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy", "iam:DeletePolicy",
          "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:ListPolicyVersions", "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion"
        ]
        Resource = "arn:aws:iam::${local.account_id}:policy/${var.cluster_name}-*"
      },
      {
        Sid    = "IAMOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider"
        ]
        Resource = "arn:aws:iam::${local.account_id}:oidc-provider/*"
      },
      {
        Sid    = "IAMInstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile"
        ]
        Resource = "arn:aws:iam::${local.account_id}:instance-profile/${var.cluster_name}-*"
      },
      # ── CloudWatch Logs: scoped to cluster log group ──
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:DescribeLogGroups", "logs:PutRetentionPolicy",
          "logs:TagLogGroup", "logs:ListTagsLogGroup",
          "logs:ListTagsForResource", "logs:TagResource"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/eks/${var.cluster_name}/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:${var.cluster_name}-vpc-flow-logs:*"
        ]
      },
      # ── KMS: scoped with tag conditions ──
      {
        Sid    = "KMSCreateKey"
        Effect = "Allow"
        Action = "kms:CreateKey"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = "berkeley-visitor-counter"
          }
        }
      },
      {
        Sid    = "KMSManageKeys"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias", "kms:DeleteAlias",
          "kms:DescribeKey", "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus", "kms:ListAliases",
          "kms:ListResourceTags", "kms:TagResource",
          "kms:EnableKeyRotation", "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion", "kms:Encrypt",
          "kms:Decrypt", "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:${local.region}:${local.account_id}:key/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "berkeley-visitor-counter"
          }
        }
      },
      {
        Sid    = "KMSListAliases"
        Effect = "Allow"
        Action = "kms:ListAliases"
        Resource = "*"
      },
      # ── S3: Terraform state ──
      {
        Sid    = "S3TerraformState"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::berkeley-tf-state",
          "arn:aws:s3:::berkeley-tf-state/*"
        ]
      },
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}

# Attach policy to cluster manager user
resource "aws_iam_user_policy_attachment" "cluster_manager" {
  user       = module.cluster_manager_user.iam_user_name
  policy_arn = module.cluster_manager_policy.arn
}

# Developer role - multiple devs can assume this
module "developer_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  role_name         = "${var.cluster_name}-developer-role"
  create_role       = true
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}

###############KMS##################

# KMS key for EKS secrets encryption
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption - ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

###############VPC##################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr


  azs = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnets))
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway
  enable_dns_hostnames   = true
  enable_dns_support     = true

  #VPC Flow Logs for network auditing
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  public_subnet_tags = {
    "kubernetes.io/role/elb"                   = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"          = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}

###############EKS##################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # PROD: private-only API endpoint — access via VPN/bastion
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # PROD: all log types enabled
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # PROD: encrypt K8s secrets at rest with CMK
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Whoever runs terraform apply gets admin automatically
  enable_cluster_creator_admin_permissions = true

  # Additional user access
  access_entries = {
    cluster_manager = {
      principal_arn = module.cluster_manager_user.iam_user_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    developers = {
      principal_arn = module.developer_role.iam_role_arn
      policy_associations = {
        dev = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["dev", "sit"]
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types # PROD: multiple types for capacity flexibility
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # PROD: encrypt node EBS volumes
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = aws_kms_key.eks.arn
            delete_on_termination = true
          }
        }
      }

      enable_monitoring = true

      labels = {
        Environment = var.environment
      }

      tags = {
        Environment = var.environment
        Project     = "berkeley-visitor-counter"
        ManagedBy   = "terraform"
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}

###############ELASTICACHE##################

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  replication_group_id = "${var.cluster_name}-redis"

  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type

  # PROD: minimum 2 nodes for failover
  num_cache_clusters         = var.redis_num_cache_clusters
  automatic_failover_enabled = var.redis_num_cache_clusters > 1
  multi_az_enabled           = var.redis_num_cache_clusters > 1

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  # PROD: maintenance and backup windows
  auto_minor_version_upgrade = true
  maintenance_window         = "sun:05:00-sun:07:00"
  snapshot_retention_limit   = 7
  snapshot_window            = "03:00-05:00"

  # Security group - only EKS nodes can access
  vpc_id = module.vpc.vpc_id
  security_group_rules = {
    ingress_eks = {
      description                  = "Allow Redis access from EKS nodes only"
      referenced_security_group_id = module.eks.node_security_group_id
    }
  }

  # Subnet group - private subnets
  subnet_ids = module.vpc.private_subnets

  # Parameter group
  create_parameter_group = true
  parameter_group_family = "redis7"

  tags = {
    Environment = var.environment
    Project     = "berkeley-visitor-counter"
    ManagedBy   = "terraform"
  }
}
