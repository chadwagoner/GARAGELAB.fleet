{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.profilarr = {
    image = "ghcr.io/dictionarry-hub/profilarr:2.1.0@sha256:75a43c9c19c70f6e48315d4ed5cef3232d905da8fab397391a2078a5e0fd7ec1";
    environment = {
      PGID = "100";
      PUID = "1000";
      ORIGIN = "https://profilarr.${config.fleet.tailscale.magicDnsSuffix}";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "profilarr";
      "docktail.service.port" = "6868";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "profilarr.config:/config"
    ];
  };

  systemd.services.podman-profilarr.serviceConfig.Restart = lib.mkForce "always";
}
