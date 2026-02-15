# General
region       = "ap-southeast-1"
environment  = "nonprod"
cluster_name = "berkeley-nonprod"

# VPC
vpc_cidr        = "10.2.0.0/16"
private_subnets = ["10.2.10.0/24", "10.2.20.0/24"]
public_subnets  = ["10.2.1.0/24", "10.2.2.0/24"]

# EKS
cluster_version                = "1.31"
node_instance_types            = ["t3.medium"]
node_min_size                  = 2
node_max_size                  = 5
node_desired_size              = 2
cluster_endpoint_public_access = false

# ElastiCache
redis_engine_version     = "7.1"
redis_node_type          = "cache.t3.medium"
redis_num_cache_clusters = 2

# IAM
admin_username = "berkeley-cluster-manager"
