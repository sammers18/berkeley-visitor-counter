data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

###############IAM##################

# Cluster Manager user
module "cluster_manager_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 5.0"

  name          = var.admin_username
  force_destroy = true

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
      {
        Sid      = "EKSAccess"
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      },
      {
        Sid    = "VPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:*Vpc*", "ec2:*Subnet*", "ec2:*Gateway*",
          "ec2:*Route*", "ec2:*SecurityGroup*", "ec2:*NetworkAcl*",
          "ec2:*Address*", "ec2:*Tag*", "ec2:Describe*",
          "ec2:CreateLaunchTemplate*", "ec2:DeleteLaunchTemplate*",
          "ec2:RunInstances"
        ]
        Resource = "*"
      },
      {
        Sid      = "ElastiCacheAccess"
        Effect   = "Allow"
        Action   = ["elasticache:*"]
        Resource = "*"
      },
      {
        Sid    = "IAMForEKS"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:TagRole",
          "iam:UntagRole", "iam:PassRole",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
          "iam:CreatePolicy", "iam:DeletePolicy",
          "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:DescribeLogGroups", "logs:PutRetentionPolicy",
          "logs:TagLogGroup", "logs:ListTagsLogGroup",
          "logs:ListTagsForResource", "logs:TagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSForEKS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:CreateAlias", "kms:DeleteAlias",
          "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus",
          "kms:ListAliases", "kms:ListResourceTags", "kms:TagResource",
          "kms:EnableKeyRotation", "kms:PutKeyPolicy", "kms:ScheduleKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3TerraformState"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::berkeley-samia-tf-state",
          "arn:aws:s3:::berkeley-samia-tf-state/*"
        ]
      }
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

###############VPC##################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

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

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_enabled_log_types = ["api", "audit", "authenticator"]

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
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      labels = {
        Environment = var.environment
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

  num_cache_clusters         = var.redis_num_cache_clusters
  automatic_failover_enabled = var.redis_num_cache_clusters > 1 ? true : false
  multi_az_enabled           = var.redis_num_cache_clusters > 1 ? true : false

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

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


