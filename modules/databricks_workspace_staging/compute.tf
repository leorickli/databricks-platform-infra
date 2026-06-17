resource "databricks_cluster" "shared_autoscaling" {
  cluster_name            = "Staging Shared"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.general_purpose.id
  driver_node_type_id     = data.databricks_node_type.general_purpose.id
  data_security_mode      = "USER_ISOLATION"
  autotermination_minutes = 30
  no_wait                 = true

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

resource "databricks_cluster" "developer" {
  cluster_name            = "Developer's Staging Cluster"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.general_purpose.id
  driver_node_type_id     = data.databricks_node_type.general_purpose.id
  data_security_mode      = "SINGLE_USER"
  single_user_name        = "developer@example.com"
  autotermination_minutes = 30
  no_wait                 = true

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
