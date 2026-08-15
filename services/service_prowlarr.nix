{ lib, ... }:

{
  virtualisation.oci-containers.containers.prowlarr = {
    image = "ghcr.io/linuxserver/prowlarr:2.5.2@sha256:1295cff29d10b486c0d8324d1559a552140a5932bf8b3d87e398654414f63f92";
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
