# Generate console client configuration files for testing in subfolder "generated/client-configs"
# PLEASE NOTE THAT THESE FILES CONTAIN SENSITIVE CREDENTIALS
resource "local_sensitive_file" "client_config_files" {
  # Do not generate any files if var.ccloud_cluster_generate_client_config_files is false
  # for_each = var.ccloud_cluster_generate_client_config_files ? [ "consumer" ] : []
  count = var.ccloud_cluster_generate_client_config_files ? 1 : 0

  content = templatefile("${path.module}/templates/client.conf.tpl",
  {
    client_name = "audit-log"
    cluster_bootstrap_server = var.ccloud_audit_log_bootstrap_server
    api_key = var.ccloud_audit_log_api_key.key
    api_secret = var.ccloud_audit_log_api_key.secret
    topic = var.ccloud_cluster_audit_log_topic
  }
  )
  filename = "${path.module}/generated/client-configs/client-audit-log.conf"
}
