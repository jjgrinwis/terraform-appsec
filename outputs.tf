
/* output "security_config_name_hostnames" {
  description = "Hostnames attached to this security configuration"
  value       = local.security_policy_hostnames
} */
output "hostnames_by_policy" {
  description = "Map of security policies and their assigned hostnames (fully managed by incoming data)"
  value       = local.hostnames_by_policy
}

output "duplicate_hostname_assignments" {
  description = "Hostnames that are assigned to multiple security policies (this should be empty!)"
  value       = local.duplicate_hostname_assignments
}
