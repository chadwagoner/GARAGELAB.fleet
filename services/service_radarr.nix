{ config, lib, ... }:

let
  mediaMount = config.fleet.nfs.mounts.media.mountPoint;
in
{
  virtualisation.oci-containers.containers.radarr = {
    image = "ghcr.io/linuxserver/radarr:6.3.0@sha256:119aaa4a4f7349bcd2a136c5373a0d7925b5479915c7dfe0c0ad352db2a6d438";
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
