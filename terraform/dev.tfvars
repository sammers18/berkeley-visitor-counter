# General
region       = "ap-southeast-1"
environment  = "dev"
cluster_name = "berkeley-eks-cluster"

# VPC
vpc_cidr           = "10.1.0.0/16"
private_subnets    = ["10.1.10.0/24"]
public_subnets     = ["10.1.1.0/24"]
single_nat_gateway = true

# EKS
cluster_version                = "1.34"
node_instance_types            = ["t3.small"]
node_min_size                  = 1
node_max_size                  = 2
node_desired_size              = 1
cluster_endpoint_public_access = true

# ElastiCache
redis_node_type          = "cache.t3.small"
redis_num_cache_clusters = 1
redis_engine_version     = "7.1"

# IAM
admin_username = "berkeley-cluster-manager"
