# Mock data for testing without Terraform Cloud
# This file contains sample hostname and security policy configurations
# When use_mock_data is set to false, real TFE outputs will be used instead
# When testing, make sure the hostnames exists otherwise the code will fail!

locals {
  mock_tfe_outputs = {
    "property-1" = {
      nonsensitive_values = {
        security_policy = "low"
        hostnames       = ["ew.grinwis.com", "bms.grinwis.com"]
      }
    }
    "property-2" = {
      nonsensitive_values = {
        security_policy = "medium"
        hostnames       = ["wss.grinwis.com"]
      }
    }
    "property-3" = {
      nonsensitive_values = {
        security_policy = "high"
        hostnames       = ["bmp.grinwis.com"]
      }
    }
  }
}
