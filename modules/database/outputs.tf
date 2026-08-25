# Database Module Outputs

output "atp_database" {
  description = "ATP database details"
  value = var.create_atp ? {
    id                     = oci_database_autonomous_database.atp[0].id
    display_name           = oci_database_autonomous_database.atp[0].display_name
    db_name                = oci_database_autonomous_database.atp[0].db_name
    connection_strings     = oci_database_autonomous_database.atp[0].connection_strings
    state                  = oci_database_autonomous_database.atp[0].state
    private_endpoint_ip    = oci_database_autonomous_database.atp[0].private_endpoint_ip
    private_endpoint_label = oci_database_autonomous_database.atp[0].private_endpoint_label
  } : null
  sensitive = true
}

output "adw_database" {
  description = "ADW database details"
  value = var.create_adw ? {
    id                     = oci_database_autonomous_database.adw[0].id
    display_name           = oci_database_autonomous_database.adw[0].display_name
    db_name                = oci_database_autonomous_database.adw[0].db_name
    connection_strings     = oci_database_autonomous_database.adw[0].connection_strings
    state                  = oci_database_autonomous_database.adw[0].state
    private_endpoint_ip    = oci_database_autonomous_database.adw[0].private_endpoint_ip
    private_endpoint_label = oci_database_autonomous_database.adw[0].private_endpoint_label
  } : null
  sensitive = true
}

output "db_system" {
  description = "DB System details"
  value = var.create_db_system ? {
    id           = oci_database_db_system.db_system[0].id
    display_name = oci_database_db_system.db_system[0].display_name
    shape        = oci_database_db_system.db_system[0].shape
    node_count   = oci_database_db_system.db_system[0].node_count
    state        = oci_database_db_system.db_system[0].state
    standby_id   = var.db_system_config.enable_dataguard ? oci_database_db_system.standby_db_system[0].id : null
  } : null
  sensitive = true
}

output "wallets" {
  description = "Database wallet files (base64 encoded)"
  value = {
    atp = var.create_atp ? data.oci_database_autonomous_database_wallet.atp_wallet[0].content : null
    adw = var.create_adw ? data.oci_database_autonomous_database_wallet.adw_wallet[0].content : null
  }
  sensitive = true
}

output "connection_strings" {
  description = "Database connection strings"
  value = {
    atp = var.create_atp ? oci_database_autonomous_database.atp[0].connection_strings : null
    adw = var.create_adw ? oci_database_autonomous_database.adw[0].connection_strings : null
  }
  sensitive = true
}