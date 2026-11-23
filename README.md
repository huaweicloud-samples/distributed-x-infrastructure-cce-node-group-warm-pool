# distributed-x-infrastructure-cce-node-group-warm-pool

[![License: MIT No Attribution](https://img.shields.io/badge/License-MIT_No_Attribution-yellow.svg)](https://opensource.org/license/mit-0)
[![Huawei Cloud](https://img.shields.io/badge/Cloud-Huawei_Cloud-red.svg)](https://www.huaweicloud.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet.svg)](https://www.terraform.io/)

## 1. 简介 / Overview

### 简介


本实践演示如何在华为云 CCE（Cloud Container Engine）上配置**自管理节点组**，并利用弹性伸缩（AS）的**预热池（Warm Pool）**加速节点扩容。预热池预先创建并保持一组 stopped 状态的 ECS 实例，当集群需要扩容时直接启动这些实例，跳过从零创建的等待时间。配合**生命周期挂钩（Lifecycle Hook）**，可在节点加入或退出集群前后执行自定义操作。

适用于需要快速响应负载波动、减少节点扩容延迟的 Kubernetes 运维场景。

---

## 2. 目录


- [1. 简介 / Overview](#1-简介--overview)
- [2. 目录](#2-目录)
- [3. 架构图](#3-架构图)
- [4. 方案亮点](#4-方案亮点)
- [5. 涉及云服务](#5-涉及云服务)
- [6. 前置条件](#6-前置条件)
- [7. 快速开始](#7-快速开始)
- [8. 分步部署](#8-分步部署)
- [9. 使用方法 / 验证](#9-使用方法--验证)
- [10. 清理资源](#10-清理资源)
- [11. 详细说明](#11-详细说明)
- [12. 依赖](#12-依赖)
- [13. FAQ / 故障排除](#13-faq--故障排除)
- [14. 贡献指南](#14-贡献指南)
- [15. 许可证](#15-许可证)
- [16. 联系方式 / 维护者](#16-联系方式--维护者)



---

## 3. 架构图

```
┌─────────────────────────────────────────────────────────┐
│                    华为云 VPC                            │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │              CCE 集群（控制面）                     │  │
│  │              cluster: warm-pool-cluster            │  │
│  └───────────────────┬───────────────────────────────┘  │
│                      │                                  │
│  ┌───────────────────┴───────────────────────────────┐  │
│  │         AS 伸缩组（自管理节点组）                    │  │
│  │                                                    │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────────┐   │  │
│  │  │ ECS 节点 │  │ ECS 节点 │  │  预热池          │   │  │
│  │  │ (Active) │  │ (Active) │  │  ┌──────────┐  │   │  │
│  │  └─────────┘  └─────────┘  │  │ECS(stopped)│  │   │  │
│  │                            │  └──────────┘  │   │  │
│  │  生命周期挂钩:              │  ┌──────────┐  │   │  │
│  │  • node-launch-hook        │  │ECS(stopped)│  │   │  │
│  │  • node-terminate-hook     │  └──────────┘  │   │  │
│  │                            └─────────────────┘   │  │
│  │                                                    │  │
│  │  伸缩策略:                                          │  │
│  │  • scale-up  (CPU > 70% → +1 实例)                 │  │
│  │  • scale-down (CPU < 30% → -1 实例)                │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  IAM 委托: cce-autoscaler-agency (AS FullAccess)        │
└─────────────────────────────────────────────────────────┘
```

---

## 4. 方案亮点

- **预热池加速扩容**：预先保持 stopped 实例，扩容时直接启动，将节点加入集群的时间从分钟级降至秒级
- **生命周期挂钩**：在节点加入/退出集群前后拦截，支持自定义初始化和排水逻辑
- **自管理节点组**：通过 AS 伸缩组管理 ECS 实例，不依赖 CCE 托管节点池，获得更大的控制灵活性
- **告警驱动自动伸缩**：基于 CES 告警（CPU 利用率）自动触发扩缩容策略
- **一键 Terraform 部署**：全部资源通过 Terraform 声明式管理，支持版本控制和重复部署

---

## 5. 涉及云服务

| 服务 | 用途 |
|------|------|
| CCE（云容器引擎） | Kubernetes 集群控制面 |
| AS（弹性伸缩） | 伸缩组、伸缩配置、预热池、生命周期挂钩、伸缩策略 |
| ECS（弹性云服务器） | 集群工作节点（由 AS 管理） |
| VPC（虚拟私有云） | 网络隔离 |
| IAM（统一身份认证） | 委托授权 |
| CES（云监控服务） | 告警规则驱动伸缩 |
| KPS（密钥对服务） | 节点 SSH 密钥 |

清理资源提示：部署完成后，如不再使用，请按「清理资源」章节执行 `terraform destroy` 释放所有资源，避免残留。

---

## 6. 前置条件

1. **华为云账号**：已完成实名认证，拥有 AK/SK（在「我的凭证」页面获取）
2. **Terraform**：>= 1.5（如未安装，参考 [Terraform 安装指南](https://developer.hashicorp.com/terraform/install)）
3. **区域与可用区**：默认使用 `cn-north-4`（北京四），可按需修改
4. **CCE 节点镜像 ID**：需从 IMS 控制台获取 CCE 节点镜像 ID 并填入 `node_image_id` 变量
5. **IAM 委托域名**：需将 `domain_name` 变量替换为实际华为云账号域名

---

## 7. 快速开始

```bash
# 1. 配置凭证
export HW_ACCESS_KEY="your-access-key"
export HW_SECRET_KEY="your-secret-key"

# 2. 进入部署目录
cd distributed-x-infrastructure-cce-node-group-warm-pool/infra

# 3. 初始化 Terraform
terraform init

# 4. 查看部署计划
terraform plan

# 5. 部署
terraform apply
```

---

## 8. 分步部署

### 步骤 1：初始化

```bash
cd distributed-x-infrastructure-cce-node-group-warm-pool/infra
terraform init
```

预期输出包含 `Terraform has been successfully initialized!`。

### 步骤 2：配置变量

创建 `terraform.tfvars` 文件，填入实际参数：

```hcl
region    = "cn-north-4"
node_image_id = "your-cce-node-image-id"
domain_name   = "your-huaweicloud-domain"
```

### 步骤 3：查看部署计划

```bash
terraform plan -var-file=terraform.tfvars
```

确认将创建以下资源：
- 1 × VPC + 1 × 子网 + 1 × 安全组
- 1 × CCE 集群
- 1 × SSH 密钥对（如未指定已有密钥）
- 1 × IAM 委托
- 1 × AS 伸缩配置 + 1 × AS 伸缩组
- 1 × AS 预热池
- 2 × AS 生命周期挂钩
- 2 × AS 伸缩策略（关联手动创建的 CES 告警规则，详见 as.tf 注释）

### 步骤 4：执行部署

```bash
terraform apply -var-file=terraform.tfvars
```

输入 `yes` 确认部署。

---

## 9. 使用方法 / 验证

### 使用方法


### 验证 CCE 集群状态

```bash
# 获取集群 ID
CLUSTER_ID=$(terraform output -raw cluster_id)

# 查询集群状态
hcloud CCE ShowCluster --cluster_id "$CLUSTER_ID"
```

预期：集群状态为 `Available`。

### 验证 AS 伸缩组

```bash
# 获取伸缩组 ID
GROUP_ID=$(terraform output -raw as_group_id)

# 查询伸缩组详情
hcloud AS ShowScalingGroup --scaling_group_id "$GROUP_ID"
```

预期：伸缩组状态为 `INSERVICE`，期望实例数与配置一致。

### 验证预热池

```bash
# 查询预热池实例
hcloud AS ListWarmPoolInstances --scaling_group_id "$GROUP_ID"
```

预期：返回 stopped 状态的实例，数量 >= `warm_pool_min_size`。

### 验证生命周期挂钩

```bash
# 查询生命周期挂钩
hcloud AS ListLifecycleHooks --scaling_group_id "$GROUP_ID"
```

预期：返回 `node-launch-hook` 和 `node-terminate-hook` 两个挂钩。

### 触发扩容测试

```bash
# 手动修改期望实例数触发扩容
hcloud AS UpdateScalingGroup --scaling_group_id "$GROUP_ID" --desire_instance_number 4

# 观察预热池实例状态变化
hcloud AS ListWarmPoolInstances --scaling_group_id "$GROUP_ID"
```

预期：预热池中的 stopped 实例被启动，直接加入伸缩组，无需等待新实例创建。

> **验证提醒**：部署完成后，请按上述步骤自行验证，确认集群、伸缩组、预热池和生命周期挂钩均正常工作，方可视为部署成功。

---

## 10. 清理资源

```bash
terraform destroy -var-file=terraform.tfvars
```

输入 `yes` 确认销毁。此操作将释放所有创建的资源（CCE 集群、AS 伸缩组及实例、VPC 等），避免资源残留。

---

## 11. 详细说明

### 预热池工作原理

预热池（Warm Pool）是 AS 弹性伸缩的一项能力，用于维护一组预创建的 stopped 状态实例：

1. **平时**：预热池保持 `min_size` 个 stopped 实例，不占用计算资源（仅保留系统盘存储）
2. **扩容时**：伸缩组优先从预热池启动 stopped 实例，跳过 ECS 创建流程（通常需 1-2 分钟），实现秒级扩容
3. **缩容后**：销毁的实例不立即删除，而是回到预热池变为 stopped 状态，供下次扩容使用
4. **容量上限**：`max_group_prepared_capacity` 限制活跃实例 + 预热实例的总数，控制预热池规模

### 生命周期挂钩

生命周期挂钩在伸缩组实例生命周期关键节点拦截：

- **INSTANCE_LAUNCHING**：实例启动时触发，可等待节点就绪后再放行
- **INSTANCE_TERMINATING**：实例销毁时触发，可执行排水（drain）操作后再放行

挂钩超时后默认放行（`default_result = CONTINUE`），也可配置为 `ABANDON`（放弃操作）。

### 自管理节点组 vs CCE 节点池

| 特性 | CCE 节点池（托管） | 自管理节点组（AS 伸缩组） |
|------|-------------------|--------------------------|
| 节点管理 | CCE 自动管理 | 用户通过 AS 管理 |
| 预热池 | 不支持 | ✅ 支持 |
| 生命周期挂钩 | 不支持 | ✅ 支持 |
| 自定义伸缩策略 | 有限 | ✅ 灵活 |
| 运维复杂度 | 低 | 中 |

本实践选择自管理节点组以获得预热池和生命周期挂钩能力。

---

## 12. 依赖

| 依赖 | 版本要求 |
|------|---------|
| Terraform | >= 1.5 |
| huaweicloud Provider | ~> 1.70 |
| random Provider | ~> 3.5 |
| hcloud CLI（可选，用于验证） | 最新版 |

---

## 13. FAQ / 故障排除

### FAQ


**Q: 为什么不直接用 CCE 节点池？**
A: CCE 节点池不支持预热池和生命周期挂钩。本实践的核心目标就是演示这两种能力，因此选择通过 AS 伸缩组管理自管理节点。

**Q: 预热池中的 stopped 实例会占用资源吗？**
A: stopped 状态的 ECS 实例不占用计算资源，但其系统盘和数据盘仍然保留。资源占用远低于运行中的实例。

**Q: 如何自定义节点初始化脚本？**
A: 修改 `files/cloud-init.yaml.tpl` 文件，在 `runcmd` 部分添加自定义命令。该脚本在节点启动时执行。

**Q: 生命周期挂钩如何完成？**
A: 挂钩触发后，需调用 AS `CompleteLifecycleAction` API 通知伸缩组继续。可在 cloud-init 脚本末尾或通过 SMN 通知触发的函数中调用。

---

## 14. 贡献指南

欢迎提交 Issue 和 Pull Request。提交前请确保通过所有自检脚本。

---

## 15. 许可证

本实践采用 [MIT No Attribution](https://opensource.org/license/mit-0) 许可证。

---

## 16. 联系方式 / 维护者
| 项 | 内容 |
|---|---|
| **创建者** | [dgc-git](https://github.com/dgc-git) |
| **维护者** | [dgc-git](https://github.com/dgc-git) |
| **联系方式** | GitHub Issues / PR（见[第 14 节](#14-贡献指南)） |
