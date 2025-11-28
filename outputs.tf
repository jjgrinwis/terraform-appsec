output "hostnames_by_policy" {
  description = "Map of security policies and their assigned hostnames (fully managed by incoming data)"
  value       = local.hostnames_by_policy
}

output "security_config_hostnames" {
  description = "All hostnames assigned to the security configuration"
  value       = akamai_appsec_configuration.appsec_config.host_names
}
