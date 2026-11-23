# 架构说明

## 整体架构

本实践在华为云上部署 CCE 集群 + AS 自管理节点组 + 预热池，实现 Kubernetes 节点的快速弹性伸缩。

## 组件说明

| 组件 | 资源 | 说明 |
|------|------|------|
| CCE 集群 | huaweicloud_cce_cluster | Kubernetes 控制面 |
| VPC 网络 | huaweicloud_vpc + subnet | 网络隔离 |
| 安全组 | huaweicloud_networking_secgroup | 节点间通信 |
| AS 伸缩组 | huaweicloud_as_group + configuration | 管理 ECS 实例 |
| AS 预热池 | huaweicloud_as_warm_pool | 预置 stopped 实例 |
| 生命周期挂钩 | huaweicloud_as_lifecycle_hook | 启动/销毁拦截 |
| IAM 委托 | huaweicloud_identity_agency | CCE 访问 AS 权限 |
| SMN 主题 | huaweicloud_smn_topic | 挂钩通知 |
| 伸缩策略 | huaweicloud_as_policy | 告警驱动扩缩容 |
