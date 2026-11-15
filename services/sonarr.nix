{ config, lib, ... }:

let
  mediaMount = config.fleet.nfs.mounts.media.mountPoint;
in
{
  virtualisation.oci-containers.containers.sonarr = {
    image = "ghcr.io/linuxserver/sonarr:4.0.20@sha256:c7d1df25e428da6c9ace05daea0d34e59522978a3843ea1944812f855af4086c";
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
