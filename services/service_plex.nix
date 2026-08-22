{ lib, ... }:

{
  virtualisation.oci-containers.containers.plex = {
    image = "ghcr.io/linuxserver/plex:1.43.3@sha256:f6c58cb2f5e41cd1397bf2ed4e61ef63bd86e0736841b3ef426fabfe04606293";
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
