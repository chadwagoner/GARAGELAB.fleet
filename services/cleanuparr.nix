{ lib, ... }:

{
  virtualisation.oci-containers.containers.cleanuparr = {
    image = "ghcr.io/cleanuparr/cleanuparr:2.11.2@sha256:4093c0eb48c1926ef375e672f05ea804aacbe7d0900d203cc8716880ccf5a1df";
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
