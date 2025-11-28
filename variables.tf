variable "security_config_name" {
  description = "Name of the security configuration to be used"
  type        = string
  default     = "jgrinwis-sc"
}

# group name used to loookup contract and group ID etc.
variable "group_name" {
  description = "Akamai group to use this resource in"
  type        = string
  default     = "Akamai Demo-M-1YX7F61"
}

# a list of hostnames not managed by Terraform, but part of the security configuration
variable "non_tf_managed_hosts" {
  description = "List of hostnames that are part of the security config but not assigned to a TF managed security policy."
  type        = list(string)
  default     = ["ew.grinwis.com"]
  validation {
    condition     = length(var.non_tf_managed_hosts) == length(distinct(var.non_tf_managed_hosts))
    error_message = "All elements in the non_tf_managed_hosts list must be unique."
  }
}

# Security policy IDs for different protection levels
variable "security_policy_low" {
  description = "Security policy ID for low protection level"
  type        = string
  default     = "ewcr_207932"
  validation {
    condition     = can(regex("^[a-zA-Z0-9]+_[0-9]+$", var.security_policy_low))
    error_message = "Security policy ID must match the format: prefix_number (e.g., ewcr_207932)"
  }
}

variable "security_policy_medium" {
  description = "Security policy ID for medium protection level"
  type        = string
  default     = "6666_76098"
  validation {
    condition     = can(regex("^[a-zA-Z0-9]+_[0-9]+$", var.security_policy_medium))
    error_message = "Security policy ID must match the format: prefix_number (e.g., ewcr_207932)"
  }
}

variable "security_policy_high" {
  description = "Security policy ID for high protection level"
  type        = string
  default     = "0000_68583"
  validation {
    condition     = can(regex("^[a-zA-Z0-9]+_[0-9]+$", var.security_policy_high))
    error_message = "Security policy ID must match the format: prefix_number (e.g., ewcr_207932)"
  }
}

# Variable to control whether to use mock data (for testing) or real TFE outputs
variable "use_mock_data" {
  description = "Use mock data for testing instead of TFE outputs"
  type        = bool
  default     = true
}

# Optional: Configuration for TFE outputs when not using mock data
variable "tfe_organization" {
  description = "Terraform Cloud organization name (only used when use_mock_data is false)"
  type        = string
  default     = ""
  validation {
    condition     = var.use_mock_data || var.tfe_organization != ""
    error_message = "When use_mock_data is false, tfe_organization must be provided"
  }
}

variable "tfe_workspace" {
  description = "Terraform Cloud workspace name (only used when use_mock_data is false)"
  type        = string
  default     = ""
  validation {
    condition     = var.use_mock_data || var.tfe_workspace != ""
    error_message = "When use_mock_data is false, tfe_workspace must be provided"
  }
}
