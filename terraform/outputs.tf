output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = module.elasticache.replication_group_primary_endpoint_address
}

output "cluster_manager_arn" {
  description = "Cluster manager IAM user ARN"
  value       = module.cluster_manager_user.iam_user_arn
}

output "developer_role_arn" {
  description = "Developer IAM role ARN"
  value       = module.developer_role.iam_role_arn
}
