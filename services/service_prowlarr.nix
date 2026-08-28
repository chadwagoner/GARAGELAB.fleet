{ lib, ... }:

{
  virtualisation.oci-containers.containers.prowlarr = {
    image = "ghcr.io/linuxserver/prowlarr:2.5.2@sha256:ab91301778251f82a31bbfc87f0497376d59e84439d9a1ceff6a61d594d1e3d7";
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
