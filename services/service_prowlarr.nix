{ lib, ... }:

{
  virtualisation.oci-containers.containers.prowlarr = {
    image = "ghcr.io/linuxserver/prowlarr:2.6.5@sha256:b3b00047ed20f6ce2b16780145cb6a0acb51c9e28ea6aa6f5dcd33c7034f1797";
    environment = {
      PGID = "100";
      PUID = "1000";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "prowlarr";
      "docktail.service.port" = "9696";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "prowlarr.config:/config"
    ];
  };

  systemd.services.podman-prowlarr.serviceConfig.Restart = lib.mkForce "always";
}
