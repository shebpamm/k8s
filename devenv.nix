{ pkgs, ... }:

{
  packages = with pkgs; [
    hubble
    terraform
    cilium-cli
    talosctl
    kubectl-cnpg
    kubecolor
    argocd
  ];
  env.VAULT_ADDR = "https://vault.sorsa.cloud";
  env.theme_display_k8s_context = "yes";
  env.theme_color_scheme = "dracula";
}
