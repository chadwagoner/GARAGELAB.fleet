{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.optimise.automatic = true;

  environment.systemPackages = with pkgs; [
    curl
    git
    vim
  ];

  networking.firewall.enable = true;
}
