# General
variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
}

variable "admin_username" {
  description = "IAM username for cluster manager"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet CIDRs (one per AZ)"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to EKS API endpoint (false for prod, true for dev)"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (true for dev, false for prod HA)"
  type        = bool
  default     = false
}

variable "public_subnets" {
  description = "List of public subnet CIDRs (one per AZ)"
  type        = list(string)
}

variable "node_instance_types" {
  description = "List of EC2 instance types for EKS managed node group"
  type        = list(string)
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
}

variable "node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache node type for Redis"
  type        = string
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters (nodes) in the Redis replication group"
  type        = number
}
