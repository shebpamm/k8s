{ pkgs, ... }:

{
  packages = with pkgs; [ hubble terraform cilium-cli talosctl ];
  env.VAULT_ADDR = "https://vault.sorsa.cloud";
}
