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
  # BOOTLOADER
  # ------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
  # NFS
  # ------------------------------------------------------------
  fleet.nfs.mounts = {
    media = {
      server = "192.168.128.9";
      export = "/volume1/media";
      mountPoint = "/srv/media";
      readOnly = false;
    };

    backup = {
      server = "192.168.128.9";
      export = "/volume1/backup";
      mountPoint = "/srv/backup";
      readOnly = false;
    };
  };

  # ------------------------------------------------------------
  # NIXOS COMPATIBILITY
  # ------------------------------------------------------------
  system.stateVersion = "26.05";
}
