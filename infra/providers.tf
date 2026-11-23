provider "huaweicloud" {
  region     = var.region
  # 凭据通过 tfvars 或变量传入，切勿硬编码到源码
  # 或使用 hcloud CLI 配置文件（~/.hcloud/config/reckoncli.json）
  access_key = var.hw_access_key
  secret_key = var.hw_secret_key
  project_id = var.hw_project_id
  domain_id  = var.hw_domain_id
}
