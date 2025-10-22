terraform {
  required_version = ">= 1.10.5"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.21.0"
    }
  }
}

provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = var.skip_tls_verify
}

// CREATE KUBERNETES BACKEND
resource "vault_auth_backend" "kubernetes" {

  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  type = "kubernetes"
  path = "${var.cluster_name}-${each.value["name"]}"

}

variable "k8s_auths" {
  type = list(object({
    name           = string
    namespace      = string
    token_policies = list(string)
    token_ttl      = number
  }))
  description = "A list of k8s_auth objects"
}

variable "cluster_name" {
  type        = string
  description = "The name of the Kubernetes cluster"
  default     = "my-cluster"
}

variable "vault_addr" {
  type        = string
  description = "The address of the Vault server"
  default     = "https://vault.example.com"
}

variable "skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification for Vault connections"
  default     = false
}