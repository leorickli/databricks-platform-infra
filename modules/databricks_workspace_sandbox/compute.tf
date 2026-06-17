resource "databricks_cluster" "shared_sandbox" {
  cluster_name            = "Sandbox Shared"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.general_purpose.id
  driver_node_type_id     = data.databricks_node_type.general_purpose.id
  data_security_mode      = "USER_ISOLATION"
  autotermination_minutes = 20
  no_wait                 = false

  autoscale {
    min_workers = 1
    max_workers = 3
  }

  aws_attributes {
    instance_profile_arn   = databricks_instance_profile.data_access.id
    availability           = "SPOT"
    zone_id                = "auto"
    first_on_demand        = 0
    spot_bid_price_percent = 100
  }

  depends_on = [databricks_instance_profile.data_access]
}

resource "databricks_sql_endpoint" "sandbox_warehouse" {
  name                      = "Sandbox Warehouse"
  cluster_size              = "2X-Small"
  min_num_clusters          = 1
  max_num_clusters          = 2
  auto_stop_mins            = 1
  enable_serverless_compute = true
}
