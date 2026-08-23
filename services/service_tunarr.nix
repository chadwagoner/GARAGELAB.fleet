{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.tunarr = {
    image = "docker.io/chrisbenincasa/tunarr:1.3.13@sha256:ffaedbfd237114bd68daa50405787a6d915e89456a87e86dc9e481b700c6c1b3";
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
