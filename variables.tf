variable "subscription_id" {
  description = "Azure subscription ID in which to create the POC resources."
  type        = string
}

variable "location" {
  description = "Azure region for the POC resources."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-haproxy-dns-poc"
}

variable "admin_username" {
  description = "Administrator username for both Linux VMs."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key used to authenticate to both Linux VMs."
  type        = string
}
