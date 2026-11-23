# ============================================================================
# 输入变量
# ============================================================================

variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "project_name" {
  description = "项目名称，用作资源命名前缀"
  type        = string
  default     = "cce-warm-pool"
}

# --- CCE 集群 ---

variable "cluster_name" {
  description = "CCE 集群名称"
  type        = string
  default     = "warm-pool-cluster"
}

variable "cluster_version" {
  description = "CCE 集群版本"
  type        = string
  default     = "v1.28"
}

variable "cluster_flavor_id" {
  description = "CCE 集群规格（控制节点规格）"
  type        = string
  default     = "cce.s1.small"
}

# --- 网络 ---

variable "vpc_cidr" {
  description = "VPC 网段"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "子网网段"
  type        = string
  default     = "10.0.0.0/24"
}

variable "availability_zone" {
  description = "可用区（单可用区部署）"
  type        = string
  default     = "cn-north-4a"
}

# --- 自管理节点（ECS 实例，通过 AS 伸缩组管理）---

variable "node_flavor" {
  description = "节点 ECS 规格"
  type        = string
  default     = "s6.large.2"
}

variable "node_image_id" {
  description = "节点镜像 ID（CCE 节点镜像，从 IMS 控制台获取）"
  type        = string
  default     = ""
  # 部署时请替换为实际镜像 ID：
  # 可通过 hcloud IMS ShowImages --imagetype gold --imagename "CCE" 查询
}

variable "node_root_volume_size" {
  description = "节点系统盘大小（GB）"
  type        = number
  default     = 50
}

variable "node_data_volume_size" {
  description = "节点数据盘大小（GB）"
  type        = number
  default     = 100
}

variable "desired_capacity" {
  description = "伸缩组期望实例数"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "伸缩组最小实例数"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "伸缩组最大实例数"
  type        = number
  default     = 6
}

# --- Warm Pool（预热池）---

variable "warm_pool_min_size" {
  description = "预热池中最少保持的实例数"
  type        = number
  default     = 2
}

variable "warm_pool_max_group_prepared_capacity" {
  description = "伸缩组中可处于 Prepared 状态的最大实例数（含活跃实例 + 预热实例）"
  type        = number
  default     = 4
}

# --- 生命周期挂钩 ---

variable "lifecycle_hook_timeout" {
  description = "生命周期挂钩超时时间（秒）"
  type        = number
  default     = 300
}

# --- CES 告警规则 ID（手动创建后填入）---

variable "scale_up_alarm_id" {
  description = "扩容告警规则 ID（通过 hcloud CLI 手动创建 CES 告警规则后填入）"
  type        = string
  default     = ""
}

variable "scale_down_alarm_id" {
  description = "缩容告警规则 ID（通过 hcloud CLI 手动创建 CES 告警规则后填入）"
  type        = string
  default     = ""
}

# --- 密钥 ---

variable "key_pair_name" {
  description = "已有 SSH 密钥对名称（用于节点登录）。如留空则自动创建临时密钥对。"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "华为云账号域名（IAM 委托归属域），需替换为实际域名"
  type        = string
  default     = "your-huaweicloud-domain"
}

# --- 凭据（通过环境变量或 tfvars 传入，切勿硬编码）---

variable "hw_access_key" {
  description = "华为云 AK（建议通过 tfvars 文件传入）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "hw_secret_key" {
  description = "华为云 SK（建议通过 tfvars 文件传入）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "hw_project_id" {
  description = "华为云 Project ID（建议通过 tfvars 文件传入）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "hw_domain_id" {
  description = "华为云 Domain ID（建议通过 tfvars 文件传入）"
  type        = string
  sensitive   = true
  default     = ""
}
