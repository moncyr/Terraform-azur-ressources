variable "location" {
  description = "Région Azure"
  type        = string
  default     = "canadacentral"
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources"
  type        = string
  default     = "rg-demo-github"
}

variable "vnet_name" {
  description = "Nom du réseau virtuel"
  type        = string
  default     = "vnet-demo"
}

variable "subnet_name" {
  description = "Nom du sous-réseau"
  type        = string
  default     = "subnet-demo"
}

variable "vm_name" {
  description = "Nom de la machine virtuelle"
  type        = string
  default     = "vm-ubuntu-demo"
}

variable "vm_size" {
  description = "Taille de la VM"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Utilisateur administrateur"
  type        = string
  default     = "cyrillemonthe"
}

variable "admin_password" {
  description = "Mot de passe administrateur"
  type        = string
  sensitive   = true
  default     = "Password123"
}
