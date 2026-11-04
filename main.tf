# definition des variables
terraform {
  required_version = ">= 1.6.0"

  # Lien avec le workspace HCP Terraform (utilisé par GitHub Actions)
  cloud {
    organization = "polytechnique_first_test"
    workspaces {
      name = "Terraform-azur-ressources"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Provider azapi, utilisé pour publier l'image dans l'ACR
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# azapi utilise les mêmes variables ARM_* que azurerm
provider "azapi" {}

# Groupe de ressources

resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.common_tags
}

# Réseau virtuel

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  tags                = var.common_tags
}

# Sous-réseau

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Adresse IP publique

resource "azurerm_public_ip" "pip" {
  name                = "pip-demo"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  allocation_method   = "Static"
  tags                = var.common_tags
}

# Interface réseau

resource "azurerm_network_interface" "nic" {
  name                = "nic-demo"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
  tags = var.common_tags
}

# Machine virtuelle Ubuntu

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  size = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  tags = var.common_tags
}

# Azure Container Registry (ACR)
# Le nom doit être unique dans tout Azure : lettres et chiffres
# seulement, 5 à 50 caractères.

resource "azurerm_container_registry" "acr" {
  name                = "acrdemocyrille2026"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  sku                 = "Basic"
  admin_enabled       = true # permet au container group de s'authentifier
  tags                = var.common_tags
}

# Publication de l'image dans l'ACR
# Azure copie lui-même l'image nginx de Docker Hub vers l'ACR
# (équivalent de "az acr import"), donc aucun Docker n'est
# nécessaire sur la machine qui exécute Terraform.

resource "azapi_resource_action" "publish_nginx" {
  type        = "Microsoft.ContainerRegistry/registries@2022-12-01"
  resource_id = azurerm_container_registry.acr.id
  action      = "importImage"
  method      = "POST"

  body = {
    source = {
      registryUri = "docker.io"
      sourceImage = "library/nginx:latest"
    }
    targetTags = ["nginx:latest"]
    mode       = "Force" # écrase le tag s'il existe déjà
  }
}

# Container Docker (l'image vient de l'ACR)

resource "azurerm_container_group" "docker" {
  name                = "docker-demo"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_address_type = "Public"
  dns_name_label  = "docker-demo-cyrille"
  os_type         = "Linux"

  # Identifiants pour tirer l'image depuis l'ACR
  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }

  container {
    name   = "nginx"
    image  = "${azurerm_container_registry.acr.login_server}/nginx:latest"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = var.common_tags

  # Le conteneur n'est déployé qu'une fois l'image publiée
  depends_on = [azapi_resource_action.publish_nginx]
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = "kvdemocyrille2026"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  tenant_id = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  purge_protection_enabled = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "Set",
      "List",
      "Delete"
    ]
  }
  tags = var.common_tags
}

# Outputs

output "resource_group_name" {
  value = azurerm_resource_group.demo.name
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "subnet_name" {
  value = azurerm_subnet.subnet.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "container_name" {
  value = azurerm_container_group.docker.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
