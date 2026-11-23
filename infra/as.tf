# ============================================================================
# Layer 5: 弹性伸缩（AS）—— 自管理节点组 + 预热池 + 生命周期挂钩
# ============================================================================
#
#   1. AS 伸缩配置（as_configuration）定义 ECS 实例模板，含 cloud-init 脚本
#   2. AS 伸缩组（as_group）管理实例生命周期，关联到伸缩配置
#   3. AS 预热池（as_warm_pool）预置 stopped 实例，扩容时直接启动，跳过创建等待
#   4. AS 生命周期挂钩（as_lifecycle_hook）在实例启动/销毁前拦截，执行自定义操作
#   5. cloud-init 脚本在实例启动时将节点加入 CCE 集群

# --- SMN 主题（用于生命周期挂钩通知）---

resource "huaweicloud_smn_topic" "lifecycle" {
  name         = "${var.project_name}-lifecycle-topic"
  display_name = "CCE warm pool lifecycle hook notifications"
}

# --- AS 伸缩配置（ECS 实例模板）---

resource "huaweicloud_as_configuration" "node" {
  scaling_configuration_name = "${var.project_name}-node-config"

  instance_config {
    flavor            = var.node_flavor
    image             = var.node_image_id
    key_name          = local.effective_key_pair_name
    security_group_ids = [huaweicloud_networking_secgroup.cce_nodes.id]

    charging_mode = "postPaid"

    disk {
      disk_type   = "SYS"
      volume_type = "SAS"
      size        = var.node_root_volume_size
    }

    disk {
      disk_type   = "DATA"
      volume_type = "SAS"
      size        = var.node_data_volume_size
    }

    # cloud-init 用户数据：节点启动时加入 CCE 集群
    user_data = templatefile("${path.module}/files/cloud-init.yaml.tpl", {
      cluster_id   = huaweicloud_cce_cluster.main.id
      cluster_name = var.cluster_name
      region       = var.region
      project_name = var.project_name
    })

    # 元数据标记
    metadata = {
      cluster = var.cluster_name
      role    = "self-managed-node"
    }
  }
}

# --- AS 伸缩组 ---

resource "huaweicloud_as_group" "nodes" {
  scaling_group_name       = "${var.project_name}-node-group"
  scaling_configuration_id = huaweicloud_as_configuration.node.id
  desire_instance_number   = var.desired_capacity
  min_instance_number      = var.min_size
  max_instance_number      = var.max_size

  vpc_id = huaweicloud_vpc.main.id

  # 可用区
  available_zones = [var.availability_zone]

  # 伸缩组网络配置
  networks {
    id = huaweicloud_vpc_subnet.main.id
  }

  # 安全组
  security_groups {
    id = huaweicloud_networking_secgroup.cce_nodes.id
  }

  # 伸缩组健康检查
  health_periodic_audit_method = "NOVA_AUDIT"
  health_periodic_audit_time   = 5
  health_periodic_audit_grace_period = 600
  instance_terminate_policy    = "OLD_CONFIG_OLD_INSTANCE"

  # 删除时销毁所有实例
  delete_publicip = true

  tags = {
    project = var.project_name
    cluster = var.cluster_name
  }
}

# --- AS 预热池（Warm Pool）---
# 预热池维护一组 stopped 实例，当伸缩组扩容时直接启动这些实例，
# 跳过从零创建的等待时间，实现快速扩容。

resource "huaweicloud_as_warm_pool" "main" {
  scaling_group_id  = huaweicloud_as_group.nodes.id
  min_capacity      = var.warm_pool_min_size
  max_capacity      = var.warm_pool_max_group_prepared_capacity
}

# --- AS 生命周期挂钩：实例启动 ---
# 当伸缩组启动一个实例（从预热池或新建）时，此挂钩拦截启动事件。
# 可在此执行自定义操作（如等待节点就绪、注册到负载均衡等）。

resource "huaweicloud_as_lifecycle_hook" "node_launch" {
  scaling_group_id       = huaweicloud_as_group.nodes.id
  name                   = "node-launch-hook"
  type                   = "ADD"
  default_result         = "CONTINUE"
  timeout                = var.lifecycle_hook_timeout
  notification_topic_urn = huaweicloud_smn_topic.lifecycle.topic_urn
}

# --- AS 生命周期挂钩：实例销毁 ---
# 当伸缩组销毁一个实例时，此挂钩拦截销毁事件。
# 可在此执行清理操作（如从 CCE 集群优雅排水节点）。

resource "huaweicloud_as_lifecycle_hook" "node_terminate" {
  scaling_group_id       = huaweicloud_as_group.nodes.id
  name                   = "node-terminate-hook"
  type                   = "REMOVE"
  default_result         = "CONTINUE"
  timeout                = var.lifecycle_hook_timeout
  notification_topic_urn = huaweicloud_smn_topic.lifecycle.topic_urn
}

# --- AS 伸缩策略：基于告警的扩缩容 ---
# 配合 CES 告警实现自动扩缩容。
# 告警规则通过 hcloud CLI 手动创建（Terraform provider 的 CES alarmrule 资源存在 metric 映射 bug）。
# 部署前请先手动创建 CES 告警规则，并将告警 ID 填入 scale_up_alarm_id 和 scale_down_alarm_id 变量。

resource "huaweicloud_as_policy" "scale_up" {
  scaling_policy_name = "${var.project_name}-scale-up"
  scaling_group_id    = huaweicloud_as_group.nodes.id
  scaling_policy_type = "ALARM"
  alarm_id            = var.scale_up_alarm_id

  scaling_policy_action {
    operation       = "ADD"
    instance_number = 1
  }
}

resource "huaweicloud_as_policy" "scale_down" {
  scaling_policy_name = "${var.project_name}-scale-down"
  scaling_group_id    = huaweicloud_as_group.nodes.id
  scaling_policy_type = "ALARM"
  alarm_id            = var.scale_down_alarm_id

  scaling_policy_action {
    operation       = "REMOVE"
    instance_number = 1
  }
}
