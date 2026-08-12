{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ------------------------------------------------------------
  # HOST
  # ------------------------------------------------------------

  networking.hostName = "cobra";

  # ------------------------------------------------------------
  # TIMEZONE
  # ------------------------------------------------------------

  time.timeZone = "UTC";

  # ------------------------------------------------------------
  # NETWORK
  # ------------------------------------------------------------

  networking.networkmanager.enable = true;

  networking.useDHCP = false;
  networking.interfaces.enp86s0.ipv4.addresses = [{
    address = "192.168.128.3";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.128.1";
  networking.nameservers = [ "192.168.128.1" ];

  # ------------------------------------------------------------
  # AUTO UPGRADE
  # ------------------------------------------------------------

  # system.autoUpgrade = {
  #   enable = true;
  #   flake = "github:chadwagoner/GARAGELAB.fleet#cobra";

  #   dates = "Sun 09:00";
  #   randomizedDelaySec = "30min";

  #   allowReboot = false;
  # };

  # ------------------------------------------------------------
  # NixOS compatibility
  # ------------------------------------------------------------

  system.stateVersion = "26.05";
}
