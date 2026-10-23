{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.profilarr = {
    image = "ghcr.io/dictionarry-hub/profilarr:2.3.1@sha256:352e42dec74ecfd68d13bb198fbc6d9346e3a8c55003026e1814e59319a2176d";
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
