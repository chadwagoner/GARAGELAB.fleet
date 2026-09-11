{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.tunarr = {
    image = "docker.io/chrisbenincasa/tunarr:1.3.14@sha256:4f7e682d2ab5d595490b3a25b046283fb99d4d88706764941c099ba04e011b78";
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
    ports = [ "8000:8000" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "tunarr.data:/config/tunarr"
    ];
  };

  systemd.services.podman-tunarr.serviceConfig.Restart =
    lib.mkForce "always";

  networking.firewall.allowedTCPPorts = [ 8000 ];
}
