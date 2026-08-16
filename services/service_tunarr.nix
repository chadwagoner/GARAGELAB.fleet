{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.tunarr = {
    image = "docker.io/chrisbenincasa/tunarr:1.3.9@sha256:8d9da9d48fbeef48c51b976af40991f3f48ffe090711ce946d720e71d9d5263b";
    environment = {
      TZ = config.time.timeZone;
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "tunarr";
      "docktail.service.port" = "8000";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "tunarr.data:/config/tunarr"
    ];
  };

  systemd.services.podman-tunarr.serviceConfig.Restart =
    lib.mkForce "always";
}
