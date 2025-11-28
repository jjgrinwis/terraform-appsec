# IaC Platform Data Structure

## Overview

This module acts as a bridge between your Infrastructure as Code (IaC) management platform and Akamai AppSec. Any IaC platform can serve as the **single source of truth** for hostname-to-policy mappings.

### Supported Platforms

This module can consume data from any IaC platform that can export the required data structure:

- ✅ **Terraform Cloud** - via workspace outputs (`tfe_outputs` data source)
- ✅ **Spacelift** - via stack outputs and dependencies
- ✅ **Scalr** - via workspace outputs
- ✅ **Atlantis** - via remote state data source
- ✅ **Terragrunt** - via remote state data source
- ✅ **Terraform Enterprise** - via workspace outputs
- ✅ **env0** - via workspace outputs
- ✅ **Any platform** that can expose Terraform outputs/state
- ✅ **Mock Data** (for local testing) - defined in `mock_data.tf`

**Key Point:** Your IaC platform becomes the single source of truth for mapping hostnames to security policies. This module reads that data and enforces it in Akamai AppSec.

The data structure defines which hostnames should be assigned to which security policy level (low, medium, high).

## 🎯 What This Module Manages

### ✅ Managed by Terraform (This Module)
- **Hostnames list** in the security configuration
- **Three match targets** (low, medium, high)
  - These are dynamically created based on incoming data
  - If no hostnames for a policy level, the match target is not created

### ❌ NOT Managed by Terraform
- **Security configuration itself** (imported from Akamai Control Center)
- **Security policies** (low_policy_id, medium_policy_id, high_policy_id)
- **Security rules and settings** (WAF rules, rate limiting, etc.)
- **Other match targets** that may exist in Akamai Control Center

## 📋 Required Data Structure

### Format

The incoming data must be a **map of objects** with this structure:

```hcl
{
  "property-name-1" = {
    nonsensitive_values = {
      security_policy = "low" | "medium" | "high"
      hostnames       = ["hostname1.example.com", "hostname2.example.com"]
    }
  }
  "property-name-2" = {
    nonsensitive_values = {
      security_policy = "medium"
      hostnames       = ["hostname3.example.com"]
    }
  }
  # ... more properties
}
```

### Field Descriptions

| Field | Type | Required | Values | Description |
|-------|------|----------|--------|-------------|
| **property-name** | string (key) | Yes | Any unique identifier | Identifies the property/application |
| **nonsensitive_values** | object | Yes | - | Container for the values |
| **security_policy** | string | No | `"low"`, `"medium"`, `"high"` | Security policy level (default: `"low"`) |
| **hostnames** | list(string) | No | List of FQDNs | Hostnames to assign to this policy |

### Important Notes

1. **Property Name**: Can be any unique identifier (e.g., "app-production", "website-1", "api-service")
2. **Security Policy**: Must be one of: `"low"`, `"medium"`, `"high"`
   - Default: `"low"` if not specified
3. **Hostnames**: Must be active in Akamai (validation will fail if not)
4. **Empty Hostnames**: Properties with empty hostname lists are ignored
5. **No Duplicates**: A hostname cannot appear in multiple properties (validation will fail)

## 🔍 Example Configurations

### Example 1: Simple Configuration

```hcl
{
  "website-production" = {
    nonsensitive_values = {
      security_policy = "high"
      hostnames       = ["www.example.com", "api.example.com"]
    }
  }
  "website-staging" = {
    nonsensitive_values = {
      security_policy = "low"
      hostnames       = ["staging.example.com"]
    }
  }
}
```

**Result:**
- `www.example.com` → high security policy
- `api.example.com` → high security policy
- `staging.example.com` → low security policy

### Example 2: Multiple Properties, Same Policy

```hcl
{
  "app1-production" = {
    nonsensitive_values = {
      security_policy = "high"
      hostnames       = ["app1.example.com"]
    }
  }
  "app2-production" = {
    nonsensitive_values = {
      security_policy = "high"
      hostnames       = ["app2.example.com"]
    }
  }
  "app3-development" = {
    nonsensitive_values = {
      security_policy = "low"
      hostnames       = ["dev.example.com"]
    }
  }
}
```

**Result:**
- `app1.example.com` → high security policy
- `app2.example.com` → high security policy
- `dev.example.com` → low security policy

### Example 3: Using Defaults

```hcl
{
  "legacy-app" = {
    nonsensitive_values = {
      # security_policy not specified, defaults to "low"
      hostnames = ["legacy.example.com"]
    }
  }
}
```

**Result:**
- `legacy.example.com` → low security policy (default)

### Example 4: Complex Multi-Tenant Setup

```hcl
{
  "tenant-a-production" = {
    nonsensitive_values = {
      security_policy = "high"
      hostnames       = [
        "tenant-a.example.com",
        "api-tenant-a.example.com"
      ]
    }
  }
  "tenant-b-production" = {
    nonsensitive_values = {
      security_policy = "medium"
      hostnames       = [
        "tenant-b.example.com",
        "api-tenant-b.example.com"
      ]
    }
  }
  "shared-services" = {
    nonsensitive_values = {
      security_policy = "high"
      hostnames       = [
        "auth.example.com",
        "cdn.example.com"
      ]
    }
  }
}
```

## 🔧 Integration Guides

### Overview: Single Source of Truth

Your IaC management platform (Terraform Cloud, Spacelift, Scalr, etc.) becomes the **single source of truth** for:
- Which hostnames exist
- Which security policy each hostname should use
- Property/application groupings

This module simply reads that data and enforces it in Akamai AppSec.

### Terraform Cloud (TFE)

#### Setup

1. **Create a workspace** that outputs hostname configurations
2. **Define outputs** in that workspace:

```hcl
# In your property management workspace
output "property_security_config" {
  value = {
    "property-1" = {
      nonsensitive_values = {
        security_policy = var.environment == "production" ? "high" : "low"
        hostnames       = var.property1_hostnames
      }
    }
    "property-2" = {
      nonsensitive_values = {
        security_policy = "medium"
        hostnames       = var.property2_hostnames
      }
    }
  }
}
```

#### Consumption

3. **Configure this module** to read from TFE:

```hcl
# In terraform.tfvars
use_mock_data    = false
tfe_organization = "your-organization"
tfe_workspace    = "property-management"
```

4. **The module reads** via:

```hcl
data "tfe_outputs" "all" {
  organization = var.tfe_organization
  workspace    = var.tfe_workspace
}
```

### Spacelift

Spacelift works similarly with stack outputs:

#### Setup

1. **Create a stack** that manages your properties
2. **Define outputs** in that stack:

```hcl
output "appsec_config" {
  value = {
    for property_key, property_config in local.properties :
    property_key => {
      nonsensitive_values = {
        security_policy = property_config.security_level
        hostnames       = property_config.hostnames
      }
    }
  }
}
```

#### Consumption

3. **Reference the stack** in this module's stack:

```hcl
# In Spacelift stack dependencies
depends_on = ["property-management-stack"]

# Use Spacelift's stack outputs feature
# The data structure is automatically available
```

### Scalr

Scalr works similarly to Terraform Cloud:

#### Setup

1. **Create a workspace** that manages your properties and outputs the data structure
2. **Configure outputs** in that workspace following the required format
3. **Set up workspace dependencies** or use remote state data source

#### Consumption

```hcl
# In terraform.tfvars or use Scalr variables
use_mock_data    = false
tfe_organization = "scalr-account-id"
tfe_workspace    = "property-management"
```

### Atlantis

With Atlantis (and GitHub/GitLab workflows):

#### Setup

1. **Use remote state** stored in S3/GCS/Azure
2. **Configure your property workspace** to output the required data structure
3. **Use terraform_remote_state** data source in this module

#### Modify main.tf

```hcl
# Replace the tfe_outputs data source with:
data "terraform_remote_state" "properties" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "properties/terraform.tfstate"
    region = "us-east-1"
  }
}

# Update locals to use remote state
locals {
  tfe_outputs = var.use_mock_data ? local.mock_tfe_outputs : data.terraform_remote_state.properties.outputs.appsec_hostname_mappings
}
```

### Terragrunt

With Terragrunt:

#### Setup

1. **Configure remote state** in your terragrunt.hcl
2. **Use dependency blocks** to reference the property management module

```hcl
# terragrunt.hcl
dependency "properties" {
  config_path = "../property-management"
}

inputs = {
  use_mock_data = false
  # Pass the outputs from dependency
  property_data = dependency.properties.outputs.appsec_hostname_mappings
}
```

#### Modify main.tf

```hcl
# Add variable for Terragrunt
variable "property_data" {
  description = "Property data from Terragrunt dependency"
  type        = any
  default     = null
}

# Update locals
locals {
  tfe_outputs = var.use_mock_data ? local.mock_tfe_outputs : var.property_data
}
```

### env0

env0 works similarly to Terraform Cloud:

#### Setup

1. **Create an environment** for property management
2. **Configure outputs** in the required format
3. **Use environment dependencies** or remote state

### Generic Remote State (Any Platform)

For any platform using remote state:

1. **Use remote state data source**:
```hcl
data "terraform_remote_state" "properties" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "properties/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  tfe_outputs = data.terraform_remote_state.properties.outputs.property_security_config
}
```

2. **Modify `main.tf`** to use the remote state instead of TFE data source

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│  Source: Terraform Cloud / Spacelift / Other       │
│                                                     │
│  Output Structure:                                  │
│  {                                                  │
│    "property-1" = {                                │
│      nonsensitive_values = {                       │
│        security_policy = "high"                    │
│        hostnames = ["www.example.com"]             │
│      }                                             │
│    }                                               │
│  }                                                  │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│  This Module (AppSec Terraform)                     │
│                                                     │
│  1. Validates all hostnames are active             │
│  2. Checks for duplicate assignments                │
│  3. Groups hostnames by policy level               │
│  4. Creates/updates match targets                  │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│  Akamai AppSec Configuration                        │
│                                                     │
│  - Security Config (imported, mostly external)      │
│  - Match Targets:                                   │
│    • Low Policy → [hostnames...]                    │
│    • Medium Policy → [hostnames...]                 │
│    • High Policy → [hostnames...]                   │
└─────────────────────────────────────────────────────┘
```

## ✅ Validation Rules

The module performs these validations:

### 1. Hostname Availability Check
```
ERROR: The following hostnames are not active/selectable to be used
in the Akamai security configuration: invalid.example.com
```

**Solution**: Ensure the hostname is:
- Active in Akamai
- Associated with a property
- Not already assigned to another security configuration

### 2. Duplicate Hostname Check
```
ERROR: The following hostnames are assigned to multiple security policies:
www.example.com (low, high)
```

**Solution**: Each hostname can only be in ONE property in the incoming data.

### 3. Policy ID Format Check
```
ERROR: Security policy ID must match the format: prefix_number (e.g., ewcr_207932)
```

**Solution**: Verify your policy IDs are correct in `terraform.tfvars`

### 4. TFE Configuration Check
```
ERROR: When use_mock_data is false, tfe_organization must be provided
```

**Solution**: Set `tfe_organization` and `tfe_workspace` in `terraform.tfvars`

## 🧪 Testing with Mock Data

For local testing, use `mock_data.tf`:

```hcl
# mock_data.tf
locals {
  mock_tfe_outputs = {
    "test-property-1" = {
      nonsensitive_values = {
        security_policy = "low"
        hostnames       = ["test1.example.com"]
      }
    }
    "test-property-2" = {
      nonsensitive_values = {
        security_policy = "high"
        hostnames       = ["test2.example.com", "test3.example.com"]
      }
    }
  }
}
```

Then set in `terraform.tfvars`:
```hcl
use_mock_data = true
```

## 🎓 Real-World Example

### Scenario: Multi-Environment Property Management

You have a Terraform Cloud workspace managing Akamai properties:

**Workspace: `akamai-properties`**

```hcl
# properties.tf
variable "properties" {
  type = map(object({
    environment = string
    hostnames   = list(string)
  }))
}

locals {
  # Map environment to security policy
  environment_to_policy = {
    production  = "high"
    staging     = "medium"
    development = "low"
  }
}

# Output in the format this module expects
output "appsec_configuration" {
  value = {
    for property_name, property in var.properties :
    property_name => {
      nonsensitive_values = {
        security_policy = local.environment_to_policy[property.environment]
        hostnames       = property.hostnames
      }
    }
  }
}
```

**Input to that workspace** (`terraform.tfvars`):
```hcl
properties = {
  "web-app-prod" = {
    environment = "production"
    hostnames   = ["www.example.com", "api.example.com"]
  }
  "web-app-staging" = {
    environment = "staging"
    hostnames   = ["staging.example.com"]
  }
  "web-app-dev" = {
    environment = "development"
    hostnames   = ["dev.example.com"]
  }
}
```

**This module** (`terraform.tfvars`):
```hcl
use_mock_data    = false
tfe_organization = "my-company"
tfe_workspace    = "akamai-properties"
```

**Result**: Automatic security policy assignment based on environment!

## 🔒 Security Considerations

1. **Sensitive Data**: Use `nonsensitive_values` - hostnames are not secrets
2. **Validation**: Always validate hostnames are active before applying
3. **State Management**: Store Terraform state securely (encrypted S3, TFC, etc.)
4. **Access Control**: Limit who can modify the source data structure
5. **Audit Trail**: Use version control for all changes

## 🌟 Platform as Single Source of Truth

### The Pattern

```
┌─────────────────────────────────────────────────────────┐
│  Your IaC Management Platform                           │
│  (Terraform Cloud, Spacelift, Scalr, etc.)             │
│                                                         │
│  Teams define their applications and properties:        │
│  - Hostnames they use                                   │
│  - Security requirements (environment-based)            │
│  - Application metadata                                 │
│                                                         │
│  Platform outputs the data structure                    │
└─────────────────────────────────────────────────────────┘
                         │
                         │ Output/State/Dependency
                         ▼
┌─────────────────────────────────────────────────────────┐
│  This Module (Single Purpose)                           │
│                                                         │
│  - Reads the data structure                             │
│  - Validates hostnames                                  │
│  - Enforces assignments in Akamai                       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Akamai AppSec                                          │
│                                                         │
│  Match targets automatically updated                    │
└─────────────────────────────────────────────────────────┘
```

### Benefits

1. **Separation of Concerns**: Property teams manage hostnames, security teams manage policies
2. **Single Source of Truth**: All hostname assignments in one place
3. **Automation**: Changes propagate automatically
4. **Auditability**: All changes tracked in version control
5. **Platform Agnostic**: Works with any IaC platform

### Platform Comparison

| Platform | Integration Method | Pros | Setup Complexity |
|----------|-------------------|------|------------------|
| **Terraform Cloud** | `tfe_outputs` data source | Built-in support | Low |
| **Spacelift** | Stack dependencies | Native integration | Low |
| **Scalr** | Workspace outputs | Similar to TFC | Low |
| **Atlantis** | Remote state | Flexible | Medium |
| **Terragrunt** | Dependencies | Type-safe | Medium |
| **env0** | Environment outputs | Good for GitOps | Low |
| **Generic** | Remote state data source | Works anywhere | Medium |

## 📚 Additional Resources

### Documentation
- [Terraform Cloud Outputs](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/outputs)
- [Spacelift Stack Dependencies](https://docs.spacelift.io/concepts/stack/stack-dependencies)
- [Scalr Remote State](https://docs.scalr.com/en/latest/)
- [Terragrunt Dependencies](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#dependency)
- [Akamai AppSec Provider](https://registry.terraform.io/providers/akamai/akamai/latest/docs)

### Related Projects
- [Remote State Data Source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)

---

**Questions?** See the main [README.md](README.md) or [QUICK_START.md](QUICK_START.md) for more information.
