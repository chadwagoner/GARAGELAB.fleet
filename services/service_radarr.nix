{ config, lib, ... }:

let
  mediaMount = config.fleet.nfs.mounts.media.mountPoint;
in
{
  virtualisation.oci-containers.containers.radarr = {
    image = "ghcr.io/linuxserver/radarr:6.4.4@sha256:fc0ae3c50f8128b97e84381903ec8d6845c3a569641cb7117c124376cccb57c1";
    environment = {
      PGID = "100";
      PUID = "1000";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "radarr";
      "docktail.service.port" = "7878";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "downloads:/downloads"
      "${mediaMount}:/media"
      "radarr.config:/config"
    ];
  };

  systemd.services.podman-radarr = {
    unitConfig.RequiresMountsFor = [ mediaMount ];
    serviceConfig.Restart = lib.mkForce "always";
  };
}
