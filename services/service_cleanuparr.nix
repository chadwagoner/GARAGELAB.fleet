{ lib, ... }:

{
  virtualisation.oci-containers.containers.cleanuparr = {
    image = "ghcr.io/cleanuparr/cleanuparr:2.10.9@sha256:cfada3e5721451403a878ef67afb317692bb3afe277328b28ce4470bfba915d0";
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
