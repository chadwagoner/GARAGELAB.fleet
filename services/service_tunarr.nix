{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.tunarr = {
    image = "docker.io/chrisbenincasa/tunarr:1.3.15@sha256:ae8ec490459e773571b277e2f64248605c1ea64d49ee4d26aa01741409d60369";
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
