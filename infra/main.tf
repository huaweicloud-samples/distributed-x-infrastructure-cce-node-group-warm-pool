# ============================================================================
# Layer 1: 网络基础设施
# ============================================================================

resource "huaweicloud_vpc" "main" {
  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr
}

resource "huaweicloud_vpc_subnet" "main" {
  name       = "${var.project_name}-subnet"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = var.subnet_cidr
  gateway_ip = cidrhost(var.subnet_cidr, 1)
}

# 安全组：CCE 节点通信
resource "huaweicloud_networking_secgroup" "cce_nodes" {
  name        = "${var.project_name}-sg"
  description = "Security group for CCE self-managed nodes"
}

# 节点间互通
resource "huaweicloud_networking_secgroup_rule" "node_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.vpc_cidr
  security_group_id = huaweicloud_networking_secgroup.cce_nodes.id
}

# ============================================================================
# Layer 2: CCE 集群（控制面）
# ============================================================================
# CCE 集群提供 Kubernetes 控制面。
# 注意：这里不创建 CCE 节点池（cce_node_pool），因为节点由 AS 伸缩组
# 作为「自管理节点组」管理，以获得 warm pool 支持。

resource "huaweicloud_cce_cluster" "main" {
  name                   = var.cluster_name
  cluster_type           = "VirtualMachine"
  flavor_id              = var.cluster_flavor_id
  cluster_version        = var.cluster_version
  vpc_id                 = huaweicloud_vpc.main.id
  subnet_id              = huaweicloud_vpc_subnet.main.id
  container_network_type = "vpc-router"
  container_network_cidr = "172.16.0.0/16"

  charging_mode = "postPaid"

  tags = {
    project = var.project_name
  }
}

# ============================================================================
# Layer 3: SSH 密钥对
# ============================================================================

# 使用已有密钥对或创建临时密钥对
resource "huaweicloud_kps_keypair" "main" {
  count = var.key_pair_name == "" ? 1 : 0

  name     = "${var.project_name}-keypair"
  key_file = "${path.module}/.ssh/${var.project_name}-keypair.pem"
}

locals {
  effective_key_pair_name = var.key_pair_name != "" ? var.key_pair_name : huaweicloud_kps_keypair.main[0].name
}

# ============================================================================
# Layer 4: IAM 委托（集群自动伸缩器使用）
# ============================================================================
# CCE 集群自动伸缩器（cluster-autoscaler）需要操作 AS 服务的权限，
# 通过 IAM 委托授予 CCE 集群对 AS 的访问权限。

resource "huaweicloud_identity_agency" "cce_autoscaler" {
  name                  = "${var.project_name}-cce-agency"
  description           = "Agency for CCE cluster autoscaler to access AS"
  duration              = "FOREVER"
  delegated_domain_name = var.domain_name

  project_role {
    project = var.region
    roles = [
      "AS FullAccess",
    ]
  }
}
