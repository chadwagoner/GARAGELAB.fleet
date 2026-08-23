{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.beszel = {
    image = "docker.io/henrygd/beszel:0.18.8@sha256:4c51486968efa0b0a702c1b0967966a2e06fb250b7418f3072d2488faea27c51";
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
