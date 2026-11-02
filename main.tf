terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscriptionid
}

variable "subscription_id" {
  type = string
}

resource "azurerm_resource_group" "demo" {
  name     = "rg-demo-github"
  location = "canadacentral"
}
