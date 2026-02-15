# General
region       = "ap-southeast-1"
environment  = "dev"
cluster_name = "berkeley-eks-cluster"

# VPC
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

# EKS
cluster_version    = "1.34"
node_instance_type = "t3.medium"
node_min_size      = 1
node_max_size      = 2
node_desired_size  = 1

# ElastiCache
redis_node_type          = "cache.t3.micro"
redis_num_cache_clusters = 1
redis_engine_version     = "7.1"

# IAM
admin_username = "berkeley-cluster-manager"