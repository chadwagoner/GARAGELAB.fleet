{ lib, ... }:

{
  virtualisation.oci-containers.containers.cleanuparr = {
    image = "ghcr.io/cleanuparr/cleanuparr:2.10.12@sha256:d0212e4c66bd0522e23c5e5da5d3006bd5ff0e0de1e3ecfcf892e039d55721e2";
    environment = {
      PORT = "11011";
      # BASE_PATH = "/cleanuparr";
      PUID = "1000";
      PGID = "100";
      UMASK = "022";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "cleanuparr";
      "docktail.service.port" = "11011";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "cleanuparr.config:/config"
    ];
  };

  systemd.services.podman-cleanuparr.serviceConfig.Restart = lib.mkForce "always";
}
