data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

data "databricks_node_type" "general_purpose" {
  local_disk = true
  category   = "General Purpose"
}
