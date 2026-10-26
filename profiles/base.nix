{ inputs, ... }:

{
  imports = [
    inputs.agenix.nixosModules.default
    ../modules/common.nix
    ../modules/ssh.nix
    ../modules/tailscale.nix
    ../modules/users.nix
    ../modules/auto-upgrade.nix
  ];
}
