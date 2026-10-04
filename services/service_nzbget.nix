{ lib, ... }:

{
  virtualisation.oci-containers.containers.nzbget = {
    image = "ghcr.io/linuxserver/nzbget:26.3.20261002@sha256:f9fcc04ca26aa113a2b97aeeb90f1f8c4370234e0b620604422e19c209270ffd";
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
