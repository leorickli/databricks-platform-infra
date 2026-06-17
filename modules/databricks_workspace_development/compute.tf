resource "databricks_cluster" "shared_autoscaling" {
  cluster_name            = "Default Shared"
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

resource "databricks_cluster" "developer" {
  cluster_name            = "Developer's Cluster"
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

# --- Cluster Policies ---
resource "databricks_cluster_policy" "developers_policy" {
  name = "Developers Policy"

  definition = jsonencode({
    "node_type_id" : {
      "type" : "regex",
      "pattern" : "^(m8g|i8g|r8g|c8g)\\.(large|xlarge)$",
      "defaultValue" : "m8g.large"
    },
    "driver_node_type_id" : {
      "type" : "fixed",
      "value" : "m8g.large",
      "hidden" : true
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "maxValue" : 5,
      "defaultValue" : 2
    },
    "autoscale.min_workers" : {
      "type" : "range",
      "maxValue" : 3,
      "defaultValue" : 1
    },
    "spark_version" : {
      "type" : "fixed",
      "value" : "auto:latest-ml",
      "hidden" : true
    },
    "autotermination_minutes" : {
      "type" : "fixed",
      "value" : 20,
      "hidden" : true
    },
    "runtime_engine" : {
      "type" : "fixed",
      "value" : "STANDARD",
      "hidden" : true
    },
    "aws_attributes.ebs_volume_type" : {
      "type" : "fixed",
      "value" : "GENERAL_PURPOSE_SSD",
      "hidden" : true
    },
    "aws_attributes.ebs_volume_count" : {
      "type" : "fixed",
      "value" : 1,
      "hidden" : true
    },
    "aws_attributes.ebs_volume_size" : {
      "type" : "fixed",
      "value" : 100,
      "hidden" : true
    }
  })
}