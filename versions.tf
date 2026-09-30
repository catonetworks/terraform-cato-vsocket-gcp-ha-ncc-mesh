terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.4"
    }
    cato = {
      source  = "catonetworks/cato"
      version = "~> 0.0.46"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  required_version = ">= 0.13"
}
