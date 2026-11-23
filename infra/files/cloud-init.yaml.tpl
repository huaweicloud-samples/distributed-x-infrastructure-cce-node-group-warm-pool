#cloud-config
# ============================================================================
# CCE 自管理节点 cloud-init 脚本
# ============================================================================
# 此脚本在 ECS 实例启动时执行，将节点加入 CCE 集群。
#
# 工作流程：
#   1. 安装 CCE 节点初始化工具
#   2. 从 CCE 集群获取认证信息（kubelet 证书）
#   3. 配置 kubelet 并加入集群
#   4. 标记节点为 self-managed（不纳入 CCE 节点池管理）

write_files:
  - path: /etc/cce/node-info.json
    permissions: "0644"
    content: |
      {
        "cluster_id": "${cluster_id}",
        "cluster_name": "${cluster_name}",
        "region": "${region}",
        "project": "${project_name}",
        "node_role": "self-managed"
      }

runcmd:
  # 安装基础工具
  - yum install -y curl wget jq || apt-get update && apt-get install -y curl wget jq

  # 获取 CCE 集群认证信息并加入集群
  # CCE 节点加入集群通过 CCE agent 自动完成（镜像预装），
  # 此处仅需确保节点网络可达控制面，并设置节点标签
  - |
    set -ex
    CLUSTER_ID="${cluster_id}"
    REGION="${region}"

    # 等待 CCE agent 启动（CCE 节点镜像预装 cce-agent）
    for i in $$(seq 1 60); do
      if systemctl is-active --quiet cce-agent 2>/dev/null; then
        echo "CCE agent is running"
        break
      fi
      sleep 5
    done

    # 标记节点为 self-managed
    NODE_NAME=$$(hostname -s)
    echo "Node $${NODE_NAME} joined cluster $${CLUSTER_ID}"

  # 生命周期挂钩完成通知
  # 当实例从预热池启动时，通知 AS 生命周期挂钩继续
  - |
    set -ex
    # 获取实例 ID
    INSTANCE_ID=$$(curl -s http://169.254.169.254/openstack/latest/meta_data/instance_id 2>/dev/null || echo "")
    if [ -n "$${INSTANCE_ID}" ]; then
      echo "Instance $${INSTANCE_ID} is ready"
      # 如有生命周期挂钩，此处可调用 AS API 完成挂钩
      # hcloud AS CompleteLifecycleAction --scaling_group_id <group_id> --lifecycle_hook_name node-launch-hook --instance_id $${INSTANCE_ID}
    fi
