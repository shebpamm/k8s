{ pkgs, ... }:

{
  packages = with pkgs; [ terraform cilium-cli talosctl ];
  env.VAULT_ADDR = "https://vault.sorsa.cloud";
}
