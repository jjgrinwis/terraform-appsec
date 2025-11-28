# Akamai AppSec Terraform Configuration

A Terraform module for managing Akamai Application Security (AppSec) configurations with dynamic hostname-to-security-policy mappings.

## Overview

A lot of customers just want to manage the security settings in Akamai Control Center.
They don't want to manage WAF exceptions or custom rules as code, they just want to click some buttons. But when adding a property via Terraform, they would like automatically add that to a security policy. This Terraform module will use a single source of truth like Terraform Cloud and use that as the source to update the hostname to security policy mapping in a security configuration.

This module provides automated management of Akamai AppSec configurations, including:

- Dynamic assignment of hostnames to security policies (low, medium, high)
- Automatic validation of hostname availability
- Prevention of duplicate policy assignments
- Support for both Terraform-managed and non-managed hostnames
- Match target creation based on security policy levels

### What This Module Manages

**✅ Fully Managed by Terraform:**

- Hostnames list in the security configuration
- Three match targets (low, medium, high) based on incoming data

**❌ NOT Managed by Terraform:**

- Security configuration itself (imported from Akamai Control Center)
- Security policies and their IDs (configured in Akamai Control Center)
- WAF rules, rate limiting, and other security settings
- Other match targets that may exist outside these three
- Make sure to add non-TF managed hosts to the `non_tf_managed_hosts` list

**Data Source:** This module expects hostname-to-policy mappings from any Infrastructure as Code (IaC) management platform:

- **Terraform Cloud** - via workspace outputs
- **Spacelift** - via stack outputs
- **Scalr** - via workspace outputs
- **Atlantis** - via remote state outputs
- **Terragrunt** - via remote state data source
- **Any IaC platform** that can export the required data structure
- **Mock data** (for local testing)

See [TFE_DATA_STRUCTURE.md](TFE_DATA_STRUCTURE.md) for the required data structure format that any platform must provide.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Terraform Configuration                  │
│                                                             │
│  ┌────────────────┐       ┌──────────────────────┐          │
│  │  Data Sources  │──────▶│  Hostname Validation │          │
│  │  - Contract    │       │  - Active/Selectable │          │
│  │  - AppSec CFG  │       │  - Duplicate Check   │          │
│  │  - Hostnames   │       └──────────────────────┘          │
│  └────────────────┘                │                        │
│         │                          ▼                        │
│         │              ┌──────────────────────┐             │
│         └─────────────▶│  Policy Assignment   │             │
│                        │  - Low               │             │
│                        │  - Medium            │             │
│                        │  - High              │             │
│                        └──────────────────────┘             │
│                                 │                           │
│                                 ▼                           │
│                    ┌─────────────────────────┐              │
│                    │   Match Target Creation │              │
│                    │   (Conditional)         │              │
│                    └─────────────────────────┘              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Akamai AppSec  │
                    └─────────────────┘
```

## Features

### Hostname Management

- **Dynamic Policy Assignment**: Automatically assigns hostnames to low, medium, or high security policies
- **Validation**: Ensures all requested hostnames are active and available in Akamai
- **Duplicate Prevention**: Prevents a hostname from being assigned to multiple security policies
- **Mixed Management**: Supports both Terraform-managed and manually-managed hostnames

### Security Policies

Three security policy levels are supported:

- **Low**: Basic security protection
- **Medium**: Standard security protection
- **High**: Enhanced security protection

Each policy can have zero or more hostnames assigned. Match targets are only created when hostnames exist for a policy.

### Built-in Validations

#### 1. Hostname Availability Check

```hcl
check "validate_hostnames" {
  # Ensures all requested hostnames are active in Akamai
}
```

#### 2. Duplicate Assignment Check

```hcl
check "validate_no_duplicate_policy_assignments" {
  # Prevents hostnames from being assigned to multiple policies
}
```

## Prerequisites

- **Terraform**: >= 1.5.0 (for import functionality)
- **Akamai Provider**: >= 9.2.0
- **TFE Provider**: >= 0.51 (when using Terraform Cloud)
- **Akamai Account**: With AppSec enabled
- **Credentials**: Akamai EdgeGrid credentials configured

<!-- BEGIN_TF_DOCS -->

## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.

<!-- END_TF_DOCS -->

## Configuration

### 1. Akamai Credentials

Create or update your `~/.edgerc` file:

```ini
[default]
client_secret = your_client_secret
host = your_host.luna.akamaiapis.net
access_token = your_access_token
client_token = your_client_token
```

### 2. Variables

| Variable                 | Description                                        | Type         | Default              | Required |
| ------------------------ | -------------------------------------------------- | ------------ | -------------------- | -------- |
| `security_config_name`   | Name of the security configuration                 | string       | `my-security-config` | No       |
| `group_name`             | Akamai group name                                  | string       | `My Akamai Group`    | No       |
| `non_tf_managed_hosts`   | Hostnames not managed by Terraform                 | list(string) | `[]`                 | No       |
| `security_policy_low`    | Security policy ID for low protection              | string       | `low_12345`          | No       |
| `security_policy_medium` | Security policy ID for medium protection           | string       | `med_67890`          | No       |
| `security_policy_high`   | Security policy ID for high protection             | string       | `high_11111`         | No       |
| `use_mock_data`          | Use mock data for testing                          | bool         | `true`               | No       |
| `tfe_organization`       | Terraform Cloud organization (when not using mock) | string       | `""`                 | No       |
| `tfe_workspace`          | Terraform Cloud workspace (when not using mock)    | string       | `""`                 | No       |

### 3. Create Configuration File

Copy the example configuration file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update the security policy IDs (get these from Akamai Control Center):

```hcl
security_policy_low    = "your_low_policy_id"
security_policy_medium = "your_medium_policy_id"
security_policy_high   = "your_high_policy_id"
```

## Usage

### Basic Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd terraform-appsec
   ```

2. **Create configuration file**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your Akamai security policy IDs (see Configuration section)

4. **(Optional) Customize mock data for testing**

   The module uses mock data by default (controlled by `use_mock_data = true`). To customize the test data, edit `mock_data.tf`:

   ```hcl
   locals {
     mock_tfe_outputs = {
       "property-1" = {
         nonsensitive_values = {
           security_policy = "low"
           hostnames       = ["example1.com"]
         }
       }
     }
   }
   ```

5. **Initialize Terraform**

   ```bash
   terraform init
   ```

6. **Plan the changes**

   ```bash
   terraform plan
   ```

7. **Apply the configuration**
   ```bash
   terraform apply
   ```

### Production Setup with Terraform Cloud

For production use with Terraform Cloud, update your `terraform.tfvars`:

```hcl
# Switch to production mode
use_mock_data = false

# Configure Terraform Cloud
tfe_organization = "your-organization-name"
tfe_workspace    = "your-workspace-name"
```

The module will automatically switch from mock data to fetching real outputs from Terraform Cloud. No code changes required!

## Project Structure

```
.
├── main.tf                      # Main configuration logic
├── provider.tf                  # Provider configuration
├── variables.tf                 # Input variables
├── versions.tf                  # Terraform and provider versions
├── outputs.tf                   # Output definitions
├── mock_data.tf                 # Mock data for testing
├── terraform.tfvars.example     # Example configuration file
└── templates/
    └── match_target.tpl         # Match target JSON template
```

## Outputs

| Output                           | Description                                                   |
| -------------------------------- | ------------------------------------------------------------- |
| `hostnames_by_policy`            | Map of security policies to their assigned hostnames          |
| `duplicate_hostname_assignments` | Any hostnames assigned to multiple policies (should be empty) |

### Example Output

```hcl
hostnames_by_policy = {
  "high"   = ["www.example.com", "api.example.com"]
  "medium" = ["staging.example.com"]
  "low"    = ["dev.example.com"]
}

duplicate_hostname_assignments = {}
```

## How It Works

### Data Flow

1. **Data Sources**: Fetch contract, security configuration, and available hostnames from Akamai
2. **Hostname Validation**: Validate that all requested hostnames are active
3. **Policy Mapping**: Create a map of hostnames per security policy level
4. **Match Target Creation**: Generate match targets for each policy (if hostnames exist)
5. **Configuration Update**: Update the AppSec configuration with the new hostnames

### Key Logic

#### Hostname Flattening

```hcl
all_requested_hostnames = flatten([
  for item in local.mock_tfe_outputs :
    lookup(item.nonsensitive_values, "hostnames", [])
])
```

#### Policy Assignment

```hcl
hostnames_by_policy = {
  for policy in ["low", "medium", "high"] :
  policy => flatten([
    for item in local.security_policy_hostnames :
    item.hostnames if item.security_policy == policy
  ])
}
```

#### Conditional Resource Creation

```hcl
resource "akamai_appsec_match_target" "my_low_match_target" {
  count = length(local.hostnames_by_policy["low"]) > 0 ? 1 : 0
  # ...
}
```

## Validation and Checks

### Pre-Apply Validation

Terraform will validate the configuration before applying:

- **Invalid Hostnames**: Non-active hostnames will be rejected

  ```
  Error: The following hostnames are not active/selectable: invalid.example.com
  ```

- **Duplicate Assignments**: Hostnames assigned to multiple policies will be rejected
  ```
  Error: The following hostnames are assigned to multiple security policies:
         example.com (low, medium)
  ```

### Post-Apply Verification

Check outputs after applying:

```bash
terraform output hostnames_by_policy
terraform output duplicate_hostname_assignments
```

## Troubleshooting

### Common Issues

**Issue**: Hostname validation fails

```
Solution: Ensure the hostname is active in Akamai and associated with a property
```

**Issue**: Match target not created

```
Solution: Verify that at least one hostname is assigned to the policy level
```

**Issue**: Import errors

```
Solution: Ensure the security configuration exists in Akamai before running terraform apply
```

**Issue**: Provider authentication fails

```
Solution: Verify your ~/.edgerc file has correct credentials and section name matches provider config
```

### Debug Mode

Enable Terraform debug logging:

```bash
export TF_LOG=DEBUG
terraform apply
```

## Best Practices

1. **Use Remote State**: Store state in Terraform Cloud or S3 backend
2. **Separate Environments**: Use workspaces or separate state files for dev/staging/prod
3. **Version Control**: Track all changes in git
4. **Review Plans**: Always review `terraform plan` output before applying
5. **Backup State**: Regularly backup your Terraform state files
6. **Use Variables**: Don't hardcode values; use variables and tfvars files
7. **Test Changes**: Test configuration changes in a non-production environment first

## Security Considerations

- Never commit `.edgerc` files to version control
- Use environment variables for sensitive values when possible
- Regularly rotate Akamai API credentials
- Use least-privilege access for Akamai API credentials
- Review security policy assignments before applying changes
- Monitor AppSec configuration changes through Akamai Control Center

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:

- Create an issue in this repository
- Contact your Akamai representative
- Refer to [Akamai Terraform Provider Documentation](https://registry.terraform.io/providers/akamai/akamai/latest/docs)

## Acknowledgments

- Built with the [Akamai Terraform Provider](https://github.com/akamai/terraform-provider-akamai)
- Designed for dynamic security policy management
- Inspired by infrastructure-as-code best practices

---

**Note**: This module uses mock data by default for testing. For production use, integrate with Terraform Cloud outputs or replace mock data with your data sources.
