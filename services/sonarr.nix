{ config, lib, ... }:

let
  mediaMount = config.fleet.nfs.mounts.media.mountPoint;
in
{
  virtualisation.oci-containers.containers.sonarr = {
    image = "ghcr.io/linuxserver/sonarr:4.0.20@sha256:673dc4609a5672bc8e46069c86ffcea283a86b48d34a6c93d8da8c24a1b87571";
    environment = {
      PGID = "100";
      PUID = "1000";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "sonarr";
      "docktail.service.port" = "8989";
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
      "sonarr.config:/config"
    ];
  };

  systemd.services.podman-sonarr = {
    unitConfig.RequiresMountsFor = [ mediaMount ];
    serviceConfig.Restart = lib.mkForce "always";
  };
}
