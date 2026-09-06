output "instance_public_ip" {
  description = "Public IP of the Immich server."
  value       = oci_core_instance.immich.public_ip
}

output "immich_url" {
  description = "Where Immich will be reachable once the instance finishes bootstrapping."
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${oci_core_instance.immich.public_ip}"
}

output "ssh_command" {
  description = "SSH into the server."
  value       = "ssh ubuntu@${oci_core_instance.immich.public_ip}"
}

output "bootstrap_log_command" {
  description = "Follow the first-boot install. Immich takes several minutes to pull its images."
  value       = "ssh ubuntu@${oci_core_instance.immich.public_ip} 'sudo tail -f /var/log/immich-bootstrap.log'"
}

output "dns_record_needed" {
  description = "DNS record to create when serving Immich on a custom domain."
  value = var.domain_name != "" ? (
    "Create an A record: ${var.domain_name} -> ${oci_core_instance.immich.public_ip}"
  ) : "No domain configured; Immich is served over plain HTTP on the IP above."
}
