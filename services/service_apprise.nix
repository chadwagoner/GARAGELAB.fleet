{ lib, ... }:

{
  virtualisation.oci-containers.containers.apprise = {
    image = "docker.io/caronc/apprise:2.0.1@sha256:0b2913b15c8eb47c25345722985ffbfae701326edde21909c205d296d62dd52c";
    environment = {
      APPRISE_STATEFUL_MODE = "simple";
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
