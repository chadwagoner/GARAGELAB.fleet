{ lib, ... }:

{
  virtualisation.oci-containers.containers.plex = {
    image = "ghcr.io/linuxserver/plex:1.43.5@sha256:d6e045dac4ea2ccb94e0aa4441e02dbec9c9d306d650814eb33d20ad497a2107";
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
