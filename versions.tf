terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = "~> 9.2"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.51"
    }
  }
  required_version = ">= 1.5.0" # going to use import function
}
