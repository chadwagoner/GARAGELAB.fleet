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
  networking.interfaces.enp86s0.ipv4.addresses = [{
    address = "192.168.128.3";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.128.1";
  networking.nameservers = [ "192.168.128.1" ];

  # Tailscale routing enables IPv6 forwarding. Continue accepting router
  # advertisements so Thread border routers can publish their IPv6 routes.
  boot.kernel.sysctl."net.ipv6.conf.enp86s0.accept_ra" = 2;

  # ------------------------------------------------------------
  # TAILSCALE
  # ------------------------------------------------------------
  fleet.tailscale = {
    acceptDns = true;
    ssh = true;
    magicDnsSuffix = "unicorn-stargazer.ts.net";
    advertiseRoutes = [ "192.168.128.0/24" ];
    advertiseExitNode = true;
  };

  # ------------------------------------------------------------
  # BESZEL AGENT
  # ------------------------------------------------------------
  age.secrets.cobra-beszel-agent = {
    file = ../../secrets/cobra-beszel-agent.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  fleet.service.beszel-agent-intel = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqhWw6iQ94vH4tnuW5SBNN35y75A3OBEQdd9Wbh6tsQ";
    tokenFile = config.age.secrets.cobra-beszel-agent.path;
  };

  # ------------------------------------------------------------
  # HOMARR
  # ------------------------------------------------------------
  age.secrets.cobra-homarr-encryption-key = {
    file = ../../secrets/cobra-homarr-encryption-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  fleet.service.homarr.encryptionKeyFile =
    config.age.secrets.cobra-homarr-encryption-key.path;

  # ------------------------------------------------------------
  # HOME ASSISTANT
  # ------------------------------------------------------------
  fleet.service.home-assistant.docktailLabels = {
    "docktail.service.enable" = "true";
    "docktail.service.name" = "home-assistant";
    "docktail.service.port" = "8123";
    "docktail.service.protocol" = "http";
    "docktail.service.service-port" = "443";
    "docktail.service.service-protocol" = "https";
  };

  networking.firewall.interfaces.enp86s0 = {
    allowedTCPPorts = [
      1400 # Sonos event callbacks
      8123 # Home Assistant web UI and API
    ];
    allowedUDPPorts = [
      1900 # SSDP/UPnP discovery
      5353 # mDNS/Zeroconf discovery
    ];
  };

  # ------------------------------------------------------------
  # NFS
  # ------------------------------------------------------------
  fleet.nfs.mounts = {
    media = {
      server = "192.168.128.9";
      export = "/volume1/media";
      mountPoint = "/srv/media";
      readOnly = false;
      idleTimeout = null;
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
