data "akamai_contract" "contract" {
  group_name = var.group_name
}

# Get information about our security configuration based on name
data "akamai_appsec_configuration" "my_configuration" {
  name = var.security_config_name
}

# Get selectable hostnames that can be added to the security configuration
# These are hostnames that are active and available for use
data "akamai_appsec_selectable_hostnames" "selectable" {
  config_id = data.akamai_appsec_configuration.my_configuration.id
}

# Optional: Fetch TFE outputs when not using mock data
# Only created when use_mock_data is false
data "tfe_outputs" "all" {
  count        = var.use_mock_data ? 0 : 1
  organization = var.tfe_organization
  workspace    = var.tfe_workspace
}

locals {
  # Determine which data source to use based on use_mock_data variable
  # When use_mock_data is true, use mock data from mock_data.tf
  # When use_mock_data is false, use real TFE outputs from Terraform Cloud
  tfe_outputs = var.use_mock_data ? local.mock_tfe_outputs : data.tfe_outputs.all[0].values

  # List of all selectable (active) hostnames from Akamai
  # Combine selectable hostnames (available to add) with already assigned hostnames
  # We're going to use this to validate if requested hostnames are active
  selectable_hostnames = toset(concat(
    data.akamai_appsec_selectable_hostnames.selectable.hostnames,
    data.akamai_appsec_configuration.my_configuration.host_names
  ))

  # Flatten all hostnames from tfe_outputs (either mock data or real TFE outputs)
  all_requested_hostnames = flatten([
    for item in local.tfe_outputs : lookup(item.nonsensitive_values, "hostnames", [])
  ])

  # Find any hostnames that are NOT in the selectable hostnames list
  invalid_hostnames = [
    for hostname in local.all_requested_hostnames :
    hostname if !contains(local.selectable_hostnames, hostname)
  ]

  # Create a map of security policies and hostnames
  # Property name is the key with a list of hostnames and a property-level security policy (default: "low")
  # This variable shows which property/hostname is assigned to which security policy
  security_policy_hostnames = {
    for property_name, item in local.tfe_outputs :
    property_name => {
      security_policy = lookup(item.nonsensitive_values, "security_policy", "low")
      hostnames       = lookup(item.nonsensitive_values, "hostnames", [])
    }
    if length(lookup(item.nonsensitive_values, "hostnames", [])) > 0
  }

  # This is our flattened map of hostnames per security policy
  # Fully managed by incoming data (mock_tfe_outputs or data.tfe_outputs.all)
  # If a hostname is removed from the incoming data, it will be removed from the policy
  hostnames_by_policy = {
    for policy in ["low", "medium", "high"] :
    policy => flatten([
      for item in local.security_policy_hostnames :
      item.hostnames
      if item.security_policy == policy
    ])
  }

  # Remove the grp_ prefix from group_id if present
  group_id = replace(data.akamai_contract.contract.group_id, "grp_", "")

  # Security policy IDs that are used in the match targets
  security_policies = {
    low    = var.security_policy_low
    medium = var.security_policy_medium
    high   = var.security_policy_high
  }

  # Create a list of all hostname-policy pairs from tfe_outputs (incoming data only)
  # This is used to validate that no hostname is assigned to multiple policies in the incoming data
  incoming_hostname_policy_pairs = flatten([
    for property_name, item in local.tfe_outputs : [
      for hostname in lookup(item.nonsensitive_values, "hostnames", []) : {
        hostname = hostname
        policy   = lookup(item.nonsensitive_values, "security_policy", "low")
      }
    ]
  ])

  # Group policies by hostname to find duplicates in incoming data
  incoming_hostname_to_policies = {
    for pair in local.incoming_hostname_policy_pairs :
    pair.hostname => pair.policy...
  }

  # Filter to only show hostnames assigned to multiple DIFFERENT policies in incoming data
  duplicate_hostname_assignments = {
    for hostname, policies in local.incoming_hostname_to_policies :
    hostname => distinct(policies)
    if length(distinct(policies)) > 1
  }

  # Find hostnames that exist in both non_tf_managed_hosts and tfe_outputs
  # A hostname should be either managed by Terraform OR not managed, not both
  conflicting_managed_hosts = [
    for hostname in var.non_tf_managed_hosts :
    hostname if contains(local.all_requested_hostnames, hostname)
  ]

  # Find non-TF managed hostnames that are NOT in the selectable hostnames list
  # These hostnames cannot be added to the security configuration
  invalid_non_tf_managed_hosts = [
    for hostname in var.non_tf_managed_hosts :
    hostname if !contains(local.selectable_hostnames, hostname)
  ]
}

# Validation check to ensure all requested hostnames are active in Akamai
# This will fail the plan if any hostname is not in the selectable hostnames list
check "validate_hostnames" {
  assert {
    condition     = length(local.invalid_hostnames) == 0
    error_message = "The following hostnames are not active/selectable to be used in the Akamai security configuration: ${join(", ", local.invalid_hostnames)}"
  }
}

# Validation check to ensure no hostname is assigned to multiple security policies
check "validate_no_duplicate_policy_assignments" {
  assert {
    condition     = length(local.duplicate_hostname_assignments) == 0
    error_message = "The following hostnames are assigned to multiple security policies: ${join(", ", [for hostname, policies in local.duplicate_hostname_assignments : "${hostname} (${join(", ", policies)})"])}"
  }
}

# Validation check to ensure non-TF managed hosts don't conflict with TF managed hosts
# A hostname should be either managed by Terraform (in tfe_outputs) OR not managed (in non_tf_managed_hosts), not both
check "validate_no_conflicting_managed_hosts" {
  assert {
    condition     = length(local.conflicting_managed_hosts) == 0
    error_message = "The following hostnames exist in both non_tf_managed_hosts and tfe_outputs. A hostname cannot be both managed and non-managed: ${join(", ", local.conflicting_managed_hosts)}"
  }
}

# Validation check to ensure non-TF managed hosts are active/selectable in Akamai
# Non-TF managed hosts must also be valid hostnames that can be added to the security configuration
check "validate_non_tf_managed_hosts" {
  assert {
    condition     = length(local.invalid_non_tf_managed_hosts) == 0
    error_message = "The following non-TF managed hostnames are not active/selectable in Akamai: ${join(", ", local.invalid_non_tf_managed_hosts)}"
  }
}

# Import existing security configuration that is managed in Akamai Control Center
# This import is REQUIRED and should NOT be removed because:
# - The security configuration is managed outside of Terraform (in Akamai Control Center)
# - We only want Terraform to manage the hostnames and match targets
# - All other security settings (policies, rules, etc.) are configured in Akamai Control Center
# https://developer.hashicorp.com/terraform/language/import
import {
  to = resource.akamai_appsec_configuration.appsec_config
  id = data.akamai_appsec_configuration.my_configuration.id
}

# Security configuration resource - imported from Akamai Control Center
# This resource tracks the configuration but only manages the hostname list
# All security policies, rules, and settings are managed in Akamai Control Center
# Terraform only manages: hostnames and the three match targets (low, medium, high)
resource "akamai_appsec_configuration" "appsec_config" {
  name        = var.security_config_name
  group_id    = local.group_id
  contract_id = data.akamai_contract.contract.id
  description = "Security configuration for Akamai Terraform demo"
  # Combine non-Terraform managed hosts with the hostnames that are managed by Terraform
  # If hosts are added to the security configuration that are not managed by Terraform, they will still be preserved
  # Note: Hostnames must be active, otherwise you will get an input error
  host_names = distinct(concat(var.non_tf_managed_hosts, (flatten(values(local.hostnames_by_policy)))))

  lifecycle {
    prevent_destroy = true
  }
}

# Create match targets for each security policy level
# These three match targets (low, medium, high) are FULLY MANAGED by Terraform
# They are the ONLY resources we create/update/delete based on incoming data
# Cannot use import with count, so these match targets must be created by Terraform
# If you delete them manually in Akamai Control Center, Terraform will recreate them

# Create a new match target only if hosts exist (count > 0) to avoid catch-all behavior
# Match targets are added to the end of the list, allowing for other match targets at the top
# that may be managed outside of Terraform
resource "akamai_appsec_match_target" "my_low_match_target" {
  count     = length(local.hostnames_by_policy["low"]) > 0 ? 1 : 0
  config_id = data.akamai_appsec_configuration.my_configuration.id
  match_target = templatefile("${path.module}/templates/match_target.tpl", {
    hostnames = local.hostnames_by_policy["low"]
    policy_id = local.security_policies["low"]
  })

  depends_on = [akamai_appsec_configuration.appsec_config]
}

resource "akamai_appsec_match_target" "my_medium_match_target" {
  count     = length(local.hostnames_by_policy["medium"]) > 0 ? 1 : 0
  config_id = data.akamai_appsec_configuration.my_configuration.id
  match_target = templatefile("${path.module}/templates/match_target.tpl", {
    hostnames = local.hostnames_by_policy["medium"]
    policy_id = local.security_policies["medium"]
  })

  depends_on = [akamai_appsec_configuration.appsec_config]
}

resource "akamai_appsec_match_target" "my_high_match_target" {
  count     = length(local.hostnames_by_policy["high"]) > 0 ? 1 : 0
  config_id = data.akamai_appsec_configuration.my_configuration.id
  match_target = templatefile("${path.module}/templates/match_target.tpl", {
    hostnames = local.hostnames_by_policy["high"]
    policy_id = local.security_policies["high"]
  })

  depends_on = [akamai_appsec_configuration.appsec_config]
}
