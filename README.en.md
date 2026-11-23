# distributed-x-infrastructure-cce-node-group-warm-pool

[![License: MIT No Attribution](https://img.shields.io/badge/License-MIT_No_Attribution-yellow.svg)](https://opensource.org/license/mit-0)
[![Huawei Cloud](https://img.shields.io/badge/Cloud-Huawei_Cloud-red.svg)](https://www.huaweicloud.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet.svg)](https://www.terraform.io/)

## 1. Overview

This practice demonstrates how to configure **self-managed node groups** on Huawei Cloud CCE (Cloud Container Engine) and use the Auto Scaling (AS) **Warm Pool** to accelerate node scale-out. A warm pool pre-creates and maintains a set of stopped ECS instances; when the cluster needs to scale out, these instances are started directly, skipping the wait time to create them from scratch. Combined with **Lifecycle Hooks**, custom actions can be run before and after nodes join or leave the cluster.

It is suited to Kubernetes operations scenarios that need to respond quickly to load fluctuations and reduce node scale-out latency.

## 2. Table of Contents

- [1. Overview](#1-overview)
- [2. Table of Contents](#2-table-of-contents)
- [3. Architecture Diagram](#3-architecture-diagram)
- [4. Highlights](#4-highlights)
- [5. Cloud Services Used](#5-cloud-services-used)
- [6. Prerequisites](#6-prerequisites)
- [7. Quick Start](#7-quick-start)
- [8. Step-by-Step Deployment](#8-step-by-step-deployment)
- [9. Usage / Verification](#9-usage--verification)
- [10. Cleanup](#10-cleanup)
- [11. Detailed Explanation](#11-detailed-explanation)
- [12. Dependencies](#12-dependencies)
- [13. FAQ / Troubleshooting](#13-faq--troubleshooting)
- [14. Contributing](#14-contributing)
- [15. License](#15-license)
- [16. Contact / Maintainers](#16-contact--maintainers)

## 3. Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Huawei Cloud VPC                      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │              CCE Cluster (Control Plane)           │  │
│  │              cluster: warm-pool-cluster            │  │
│  └───────────────────┬───────────────────────────────┘  │
│                      │                                  │
│  ┌───────────────────┴───────────────────────────────┐  │
│  │         AS Scaling Group (Self-Managed Node Group) │  │
│  │                                                    │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────────┐   │  │
│  │  │ ECS Node │  │ ECS Node │  │  Warm Pool      │   │  │
│  │  │ (Active) │  │ (Active) │  │  ┌──────────┐  │   │  │
│  │  └─────────┘  └─────────┘  │  │ECS(stopped)│  │   │  │
│  │                            │  └──────────┘  │   │  │
│  │  Lifecycle Hooks:          │  ┌──────────┐  │   │  │
│  │  • node-launch-hook        │  │ECS(stopped)│  │   │  │
│  │  • node-terminate-hook     │  └──────────┘  │   │  │
│  │                            └─────────────────┘   │  │
│  │                                                    │  │
│  │  Scaling Policies:                                 │  │
│  │  • scale-up  (CPU > 70% → +1 instance)             │  │
│  │  • scale-down (CPU < 30% → -1 instance)            │  │
│  └────────────────────────────────────────────────────┘  │
│                                                         │
│  IAM Agency: cce-autoscaler-agency (AS FullAccess)        │
└─────────────────────────────────────────────────────────┘
```

## 4. Highlights

- **Warm Pool accelerates scale-out**: pre-maintains stopped instances and starts them directly on scale-out, reducing node join time from minutes to seconds
- **Lifecycle Hooks**: intercept around node join/leave events, supporting custom initialization and drain logic
- **Self-managed node group**: manages ECS instances via an AS scaling group, independent of CCE managed node pools for greater control flexibility
- **Alarm-driven auto-scaling**: automatically triggers scaling policies based on CES alarms (CPU utilization)
- **One-command Terraform deployment**: all resources are managed declaratively through Terraform, supporting version control and repeatable deployment

## 5. Cloud Services Used

| Service | Purpose |
|------|------|
| CCE (Cloud Container Engine) | Kubernetes cluster control plane |
| AS (Auto Scaling) | Scaling group, scaling configuration, warm pool, lifecycle hooks, scaling policies |
| ECS (Elastic Cloud Server) | Cluster worker nodes (managed by AS) |
| VPC (Virtual Private Cloud) | Network isolation |
| IAM (Identity and Access Management) | Agency authorization |
| CES (Cloud Eye Service) | Alarm rules driving scaling |
| KPS (Key Pair Service) | Node SSH key pair |

Cleanup reminder: after deployment, if no longer needed, run `terraform destroy` as described in the Cleanup section to release all resources and avoid residuals.

## 6. Prerequisites

1. **Huawei Cloud account**: real-name verified, with AK/SK (obtained from the "My Credentials" page)
2. **Terraform**: >= 1.5 (see the [Terraform Installation Guide](https://developer.hashicorp.com/terraform/install) if not installed)
3. **Region and AZ**: defaults to `cn-north-4` (Beijing 4), adjustable as needed
4. **CCE node image ID**: obtain a CCE node image ID from the IMS console and set it in the `node_image_id` variable
5. **IAM agency domain name**: replace the `domain_name` variable with your actual Huawei Cloud account domain name

## 7. Quick Start

```bash
# 1. Configure credentials
export HW_ACCESS_KEY="your-access-key"
export HW_SECRET_KEY="your-secret-key"

# 2. Enter the deployment directory
cd distributed-x-infrastructure-cce-node-group-warm-pool/infra

# 3. Initialize Terraform
terraform init

# 4. Review the deployment plan
terraform plan

# 5. Deploy
terraform apply
```

## 8. Step-by-Step Deployment

### Step 1: Initialize

```bash
cd distributed-x-infrastructure-cce-node-group-warm-pool/infra
terraform init
```

Expected output includes `Terraform has been successfully initialized!`.

### Step 2: Configure Variables

Create a `terraform.tfvars` file with the actual parameters:

```hcl
region    = "cn-north-4"
node_image_id = "your-cce-node-image-id"
domain_name   = "your-huaweicloud-domain"
```

### Step 3: Review the Deployment Plan

```bash
terraform plan -var-file=terraform.tfvars
```

Confirm the following resources will be created:
- 1 × VPC + 1 × Subnet + 1 × Security Group
- 1 × CCE cluster
- 1 × SSH key pair (if an existing key is not specified)
- 1 × IAM agency
- 1 × AS scaling configuration + 1 × AS scaling group
- 1 × AS warm pool
- 2 × AS lifecycle hooks
- 2 × AS scaling policies (linked to manually created CES alarm rules; see the comments in as.tf)

### Step 4: Deploy

```bash
terraform apply -var-file=terraform.tfvars
```

Type `yes` to confirm deployment.

## 9. Usage / Verification

### Verify CCE Cluster Status

```bash
# Get the cluster ID
CLUSTER_ID=$(terraform output -raw cluster_id)

# Query the cluster status
hcloud CCE ShowCluster --cluster_id "$CLUSTER_ID"
```

Expected: cluster status is `Available`.

### Verify the AS Scaling Group

```bash
# Get the scaling group ID
GROUP_ID=$(terraform output -raw as_group_id)

# Query the scaling group details
hcloud AS ShowScalingGroup --scaling_group_id "$GROUP_ID"
```

Expected: scaling group status is `INSERVICE`, and the desired instance count matches the configuration.

### Verify the Warm Pool

```bash
# Query the warm pool instances
hcloud AS ListWarmPoolInstances --scaling_group_id "$GROUP_ID"
```

Expected: returns instances in stopped state, with a count >= `warm_pool_min_size`.

### Verify Lifecycle Hooks

```bash
# Query the lifecycle hooks
hcloud AS ListLifecycleHooks --scaling_group_id "$GROUP_ID"
```

Expected: returns the two hooks `node-launch-hook` and `node-terminate-hook`.

### Trigger a Scale-Out Test

```bash
# Manually change the desired instance count to trigger scale-out
hcloud AS UpdateScalingGroup --scaling_group_id "$GROUP_ID" --desire_instance_number 4

# Observe warm pool instance status changes
hcloud AS ListWarmPoolInstances --scaling_group_id "$GROUP_ID"
```

Expected: the stopped instances in the warm pool are started and join the scaling group directly, without waiting for new instances to be created.

> **Verification reminder**: after deployment, follow these steps to verify that the cluster, scaling group, warm pool, and lifecycle hooks all work correctly before considering the deployment successful.

After deployment, follow these steps to verify that the business functionality works before considering the delivery complete.

## 10. Cleanup

```bash
terraform destroy -var-file=terraform.tfvars
```

Type `yes` to confirm destruction. This releases all created resources (CCE cluster, AS scaling group and instances, VPC, etc.) to avoid resource residuals.

## 11. Detailed Explanation

### How the Warm Pool Works

The Warm Pool is an AS capability for maintaining a set of pre-created stopped instances:

1. **Idle**: the warm pool keeps `min_size` stopped instances, which use no compute resources (only system disk storage is retained)
2. **Scale-out**: the scaling group first starts stopped instances from the warm pool, skipping the ECS creation flow (typically 1-2 minutes) to achieve second-level scale-out
3. **After scale-in**: terminated instances are not deleted immediately but return to the warm pool in stopped state for the next scale-out
4. **Capacity limit**: `max_group_prepared_capacity` limits the total of active + warm instances, controlling the warm pool size

### Lifecycle Hooks

Lifecycle hooks intercept at key points in the scaling group instance lifecycle:

- **INSTANCE_LAUNCHING**: triggered when an instance starts; it can wait until the node is ready before allowing continuation
- **INSTANCE_TERMINATING**: triggered when an instance terminates; it can perform a drain operation before allowing continuation

After the hook timeout, continuation is the default (`default_result = CONTINUE`); it can also be set to `ABANDON` (abort the operation).

### Self-Managed Node Group vs CCE Node Pool

| Feature | CCE Node Pool (Managed) | Self-Managed Node Group (AS Scaling Group) |
|------|-------------------|--------------------------|
| Node management | Auto-managed by CCE | User-managed via AS |
| Warm pool | Not supported | ✅ Supported |
| Lifecycle hooks | Not supported | ✅ Supported |
| Custom scaling policies | Limited | ✅ Flexible |
| Operational complexity | Low | Medium |

This practice uses self-managed node groups to gain warm pool and lifecycle hook capabilities.

## 12. Dependencies

| Dependency | Version Requirement |
|------|---------|
| Terraform | >= 1.5 |
| huaweicloud Provider | ~> 1.70 |
| random Provider | ~> 3.5 |
| hcloud CLI (optional, for verification) | Latest |

## 13. FAQ / Troubleshooting

**Q: Why not use CCE node pools directly?**
A: CCE node pools do not support warm pools or lifecycle hooks. The core goal of this practice is to demonstrate these two capabilities, so self-managed nodes are managed through an AS scaling group.

**Q: Do stopped instances in the warm pool consume resources?**
A: Stopped ECS instances do not consume compute resources, but their system and data disks are still retained. Resource usage is far lower than that of running instances.

**Q: How do I customize the node initialization script?**
A: Modify `files/cloud-init.yaml.tpl` and add custom commands in the `runcmd` section. The script runs when the node starts.

**Q: How is a lifecycle hook completed?**
A: After a hook triggers, call the AS `CompleteLifecycleAction` API to notify the scaling group to continue. This can be done at the end of the cloud-init script or in a function triggered by an SMN notification.

## 14. Contributing

Issues and Pull Requests are welcome. Please ensure all self-check scripts pass before submitting.

## 15. License

This practice is licensed under [MIT No Attribution](https://opensource.org/license/mit-0).

## 16. Contact / Maintainers
| Item | Content |
|---|---|
| **Creator** | [dgc-git](https://github.com/dgc-git) |
| **Maintainer** | [dgc-git](https://github.com/dgc-git) |
| **Contact** | GitHub Issues / PR (see [Section 14](#14-contributing)) |
