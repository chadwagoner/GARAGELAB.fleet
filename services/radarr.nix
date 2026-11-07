{ config, lib, ... }:

let
  mediaMount = config.fleet.nfs.mounts.media.mountPoint;
in
{
  virtualisation.oci-containers.containers.radarr = {
    image = "ghcr.io/linuxserver/radarr:6.4.4@sha256:ade5937813c6ae415b29db729386e53fea3ecf067a019849bafbe2d2a6ec02ba";
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
