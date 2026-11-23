# ============================================================================
# 输出
# ============================================================================

output "cluster_name" {
  description = "CCE 集群名称"
  value       = huaweicloud_cce_cluster.main.name
}

output "cluster_id" {
  description = "CCE 集群 ID"
  value       = huaweicloud_cce_cluster.main.id
}

output "cluster_endpoint" {
  description = "CCE 集群 API 端点"
  value       = huaweicloud_cce_cluster.main.status
}

output "vpc_id" {
  description = "VPC ID"
  value       = huaweicloud_vpc.main.id
}

output "subnet_id" {
  description = "子网 ID"
  value       = huaweicloud_vpc_subnet.main.id
}

output "as_group_id" {
  description = "AS 伸缩组 ID"
  value       = huaweicloud_as_group.nodes.id
}

output "as_configuration_id" {
  description = "AS 伸缩配置 ID"
  value       = huaweicloud_as_configuration.node.id
}

output "warm_pool_min_capacity" {
  description = "预热池最小实例数"
  value       = huaweicloud_as_warm_pool.main.min_capacity
}

output "warm_pool_max_capacity" {
  description = "伸缩组最大 Prepared 实例数"
  value       = huaweicloud_as_warm_pool.main.max_capacity
}

output "key_pair_name" {
  description = "SSH 密钥对名称"
  value       = local.effective_key_pair_name
}

output "iam_agency_name" {
  description = "IAM 委托名称（集群自动伸缩器使用）"
  value       = huaweicloud_identity_agency.cce_autoscaler.name
}
