{ lib, ... }:

{
  virtualisation.oci-containers.containers.nzbget = {
    image = "ghcr.io/linuxserver/nzbget:26.2.20260821@sha256:1dca6a4407e08313919d2780bf2a6bc17e21b947a6e8e34624b9e115795fcf8c";
    environment = {
      PGID = "100";
      PUID = "1000";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "nzbget";
      "docktail.service.port" = "6789";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "downloads:/downloads"
      "nzbget.config:/config"
    ];
  };

  systemd.services.podman-nzbget.serviceConfig.Restart = lib.mkForce "always";
}
