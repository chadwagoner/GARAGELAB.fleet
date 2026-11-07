{ lib, ... }:

{
  virtualisation.oci-containers.containers.apprise = {
    image = "docker.io/caronc/apprise:2.0.2@sha256:6ae97e24b3447f85f725a03ba73c6dc3a5f4b99f4273ac126de2d9b5ed6205d5";
    environment = {
      APPRISE_STATEFUL_MODE = "simple";
      APPRISE_WORKER_COUNT = "4";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "apprise";
      "docktail.service.port" = "8000";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [ "apprise.config:/config" ];
  };

  systemd.services.podman-apprise.serviceConfig.Restart =
    lib.mkForce "always";
}
