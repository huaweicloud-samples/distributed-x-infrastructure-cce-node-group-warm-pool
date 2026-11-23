region       = "cn-north-4"
domain_name  = "GT-dgcmy"
node_image_id = "9c2f377e-7f49-4fdf-b0be-c6c8d3b96fde"
warm_pool_min_size = 2
warm_pool_max_group_prepared_capacity = 2

# CES 告警规则 ID（部署前请先通过 hcloud CLI 手动创建告警规则，并替换以下值）
scale_up_alarm_id   = "al261009T105459SnKfkfpWN"
scale_down_alarm_id = "al261009T105515Shix72Olv"
