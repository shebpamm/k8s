terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.18.1"
    }
  }
}

provider "vault" {
  address = "https://vault.opcode.xyz"
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  path        = "kubernetes-vault-sync"
  description = "Kubernetes authentication backend for vault operator"
}

resource "vault_kubernetes_auth_backend_config" "sorsalab-kube-auth-config" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://192.168.7.99:6443"
}

resource "vault_policy" "dev" {
  name = "dev"

  policy = <<EOF
path "kube/*" {
  capabilities = ["read"]
}
EOF
}

resource "vault_kubernetes_auth_backend_role" "dev" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-operator"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["app", "dyndns"]
  token_policies                   = ["dev"]
  token_ttl                        = 3600
  audience                         = "vault"
}

resource "vault_mount" "kube" {
  path        = "kube"
  type        = "kv-v2"
  description = "Kubernetes secrets engine"
}
