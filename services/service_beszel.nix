{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.beszel = {
    image = "docker.io/henrygd/beszel:0.21.0@sha256:6b39a8b64f9b15d00a25e7683e31a93c46161182a54f62713525107064e10599";
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
