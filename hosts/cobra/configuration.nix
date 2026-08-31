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

  # ------------------------------------------------------------
  # MOSQUITTO
  # ------------------------------------------------------------
  fleet.service.mosquitto.enable = true;

  # ------------------------------------------------------------
  # ZIGBEE2MQTT
  # ------------------------------------------------------------
  # The Aeotec Z-Stick 10 Pro Zigbee interface is `if01`; `if00` is Z-Wave.
  age.secrets.cobra-zigbee2mqtt-frontend-auth-token = {
    file = ../../secrets/cobra-zigbee2mqtt-frontend-auth-token.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  fleet.service.zigbee2mqtt = {
    enable = true;
    serialDevice = "/dev/serial/by-id/usb-Silicon_Labs_CP2105_Dual_USB_to_UART_Bridge_Controller_0166114C-if01-port0";
    adapter = "ember";
    frontend = {
      enable = true;
      host = "0.0.0.0";
      port = 8080;
      authTokenFile = config.age.secrets.cobra-zigbee2mqtt-frontend-auth-token.path;
    };
  };

  networking.useDHCP = false;
  networking.interfaces.enp86s0.ipv4.addresses = [{
    address = "192.168.128.3";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.128.1";
  networking.nameservers = [ "192.168.128.1" ];

  boot.kernel.sysctl."net.ipv6.conf.enp86s0.accept_ra" = 2;
  boot.kernel.sysctl."net.ipv6.conf.enp86s0.accept_ra_rt_info_max_plen" = 64;

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
  # CONTAINER VOLUME BACKUPS
  # ------------------------------------------------------------
  age.secrets.cobra-container-backup-restic-password = {
    file = ../../secrets/cobra-container-backup-restic-password.age;
    owner = "nix";
    group = "users";
    mode = "0400";
  };

  fleet.backup.containerVolumes = {
    enable = true;
    mount = "backup";
    repositoryName = "restic";
    schedule = "Sun *-*-* 10:00:00 UTC";
    excludeVolumes = [ "downloads" ];
    passwordFile =
      config.age.secrets.cobra-container-backup-restic-password.path;

    retention = {
      weekly = 8;
      monthly = 12;
      yearly = 3;
    };
  };

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
