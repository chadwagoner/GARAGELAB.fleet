{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.beszel = {
    image = "docker.io/henrygd/beszel:0.18.7";
    environment = {
      APP_URL = "https://beszel.${config.fleet.tailscale.magicDnsSuffix}";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "beszel";
      "docktail.service.port" = "8090";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "beszel.data:/beszel_data"
    ];
  };

  systemd.services.podman-beszel.serviceConfig.Restart = lib.mkForce "always";
}
