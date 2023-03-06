terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.13.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.18.1"
    }
  }
}

provider "vault" {
  address = "https://vault.sorsa.cloud"
}

resource "vault_mount" "pki" {
  path                      = "pki"
  type                      = "pki"
  default_lease_ttl_seconds = 315360000 # 10 years
  max_lease_ttl_seconds     = 315360000 # 10 years
}

resource "vault_pki_secret_backend_root_cert" "sorsalab-root" {
  backend      = vault_mount.pki.path
  type         = "internal"
  common_name  = "sorsa.cloud"
  ttl          = "315360000" # 10 years
  format       = "pem"
  key_type     = "rsa"
  key_bits     = 4096
  organization = "Sorsalab"
}

resource "vault_pki_secret_backend_role" "sorsalab-role" {
  backend            = vault_mount.pki.path
  name               = "sorsalab-role"
  allowed_domains    = ["sorsa.cloud"]
  allow_subdomains   = true
  allow_glob_domains = true
  allow_any_name     = true
}

resource "vault_pki_secret_backend_config_urls" "sorsalab-urls" {
  backend = vault_mount.pki.path
  crl_distribution_points = [
    "https://vault.sorsa.cloud/v1/pki/crl"
  ]
  issuing_certificates = [
    "https://vault.sorsa.cloud/v1/pki/ca"
  ]
}

resource "vault_mount" "pki_k8s" {
  path                      = "pki_k8s"
  type                      = "pki"
  default_lease_ttl_seconds = 315360000 # 10 years
  max_lease_ttl_seconds     = 315360000 # 10 years
}

resource "vault_pki_secret_backend_intermediate_cert_request" "sorsalab-k8s-request" {
  backend     = vault_mount.pki_k8s.path
  type        = "internal"
  common_name = "sorsa.cloud K8s Intermediate Authority"
  key_type    = "rsa"
  key_bits    = 4096
}

resource "vault_pki_secret_backend_root_sign_intermediate" "sorsalab-k8s-signed" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.sorsalab-k8s-request]
  backend     = vault_mount.pki.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.sorsalab-k8s-request.csr
  common_name = "sorsa.cloud K8s Intermediate Authority"
  ttl         = "315360000" # 10 years
}

resource "vault_pki_secret_backend_intermediate_set_signed" "sorsalab-k8s-set-signed" {
  backend     = vault_mount.pki_k8s.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.sorsalab-k8s-signed.certificate
}

resource "vault_pki_secret_backend_role" "sorsalab-k8s-role" {
  backend          = vault_mount.pki_k8s.path
  name             = "k8s-sorsa-cloud"
  allowed_domains  = ["k8s.sorsa.cloud"]
  allow_subdomains = true
  max_ttl          = "2592000" # 30 days
}

resource "vault_policy" "sorsalab-k8s-policy" {
  name   = "sorsalab-k8s-policy"
  policy = file("issuer_policy.hcl")
}

resource "vault_auth_backend" "sorsalab-kube-auth" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "sorsalab-kube-auth-config" {
  depends_on         = [vault_auth_backend.sorsalab-kube-auth]
  backend            = "kubernetes"
  kubernetes_host    = "https://kube.sorsa.cloud:6443"
  kubernetes_ca_cert = file("kube.sorsa.cloud.crt")
}

resource "vault_kubernetes_auth_backend_role" "sorsalab-kube-auth-role" {
  depends_on                       = [vault_policy.sorsalab-k8s-policy, vault_auth_backend.sorsalab-kube-auth]
  backend                          = "kubernetes"
  role_name                        = "issuer"
  bound_service_account_names      = ["issuer"]
  bound_service_account_namespaces = ["cert-manager"]
  token_policies                   = [vault_policy.sorsalab-k8s-policy.name]
  token_ttl                        = "2592000" # 30 days
  token_max_ttl                    = "2592000" # 30 days
}

# Expose the root ca for teleport, as trust-manager is still WIP
resource "kubernetes_secret" "sorsa-root-ca" {
  metadata {
    name = "sorsa-root-ca"
    namespace = "teleport"
  }

  data = {
    "ca.pem" = vault_pki_secret_backend_root_cert.sorsalab-root.certificate
  }
}

output "root_ca" {
  value = vault_pki_secret_backend_root_cert.sorsalab-root.certificate
}
