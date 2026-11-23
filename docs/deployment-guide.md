# 部署指南

## 前置条件

1. 华为云账号已完成实名认证，拥有 AK/SK
2. Terraform >= 1.5
3. 已获取 CCE 节点镜像 ID

## 部署步骤

```bash
cd infra/
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 验证

```bash
# 验证集群状态
hcloud CCE ShowCluster --cluster_id $(terraform output -raw cluster_id)

# 验证伸缩组
hcloud AS ShowScalingGroup --scaling_group_id $(terraform output -raw as_group_id)
```

## 清理

```bash
terraform destroy -var-file=terraform.tfvars
```
