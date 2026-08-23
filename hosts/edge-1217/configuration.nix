{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ------------------------------------------------------------
  # HOST
  # ------------------------------------------------------------
  networking.hostName = "edge-1217";

  # ------------------------------------------------------------
  # BOOTLOADER
  # ------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ------------------------------------------------------------
  # BLUETOOTH
  # ------------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ------------------------------------------------------------
  # TIMEZONE
  # ------------------------------------------------------------
  time.timeZone = "UTC";

  # ------------------------------------------------------------
  # NETWORK
  # ------------------------------------------------------------
  networking.networkmanager.enable = true;

  networking.useDHCP = false;
  networking.interfaces.eno1.ipv4.addresses = [{
    address = "192.168.86.3";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.86.1";
  networking.nameservers = [ "192.168.86.1" ];

  boot.kernel.sysctl."net.ipv6.conf.eno1.accept_ra" = 2;
  boot.kernel.sysctl."net.ipv6.conf.eno1.accept_ra_rt_info_max_plen" = 64;

  # ------------------------------------------------------------
  # TAILSCALE
  # ------------------------------------------------------------
  fleet.tailscale = {
    acceptDns = true;
    ssh = true;
    magicDnsSuffix = "unicorn-stargazer.ts.net";
    advertiseRoutes = [ "192.168.86.0/24" ];
    advertiseExitNode = true;
  };

  # ------------------------------------------------------------
  # BESZEL AGENT
  # ------------------------------------------------------------
  age.secrets.beszel-agent = {
    file = ../../secrets/beszel-agent.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  fleet.service.beszel-agent-intel = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqhWw6iQ94vH4tnuW5SBNN35y75A3OBEQdd9Wbh6tsQ";
    tokenFile = config.age.secrets.beszel-agent.path;
  };

  # ------------------------------------------------------------
  # NIXOS COMPATIBILITY
  # ------------------------------------------------------------
  system.stateVersion = "26.05";
}
