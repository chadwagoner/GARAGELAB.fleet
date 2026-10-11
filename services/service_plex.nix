{ lib, ... }:

{
  virtualisation.oci-containers.containers.plex = {
    image = "ghcr.io/linuxserver/plex:1.43.4@sha256:06e07af2851e6a822e89062b148435495dd794d6d5aaf36247dee05fb3dcc4b8";
    networks = [ "host" ];
    devices = [ "/dev/dri:/dev/dri" ];
    environment = {
      PGID = "100";
      PUID = "1000";
      VERSION = "docker";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "plex-config:/config"
      "/srv/media:/media"
    ];
  };

  systemd.services.podman-plex = {
    unitConfig.RequiresMountsFor = [ "/srv/media" ];
    serviceConfig.Restart = lib.mkForce "always";
  };

  networking.firewall = {
    allowedTCPPorts = [
      8324
      32400
      32469
    ];
    allowedUDPPorts = [
      1900
      5353
      32410
      32412
      32413
      32414
    ];
  };
}
