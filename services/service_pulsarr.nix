{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.pulsarr = {
    image = "docker.io/lakker/pulsarr:0.19.2@sha256:3408e9c0cd986bb85b39749f29a1454ba2cb6b8715f85469222388636334350d";
    environment = {
      baseUrl = "http://pulsarr.${config.fleet.tailscale.magicDnsSuffix}";
      port = "3003";
      TZ = "UTC";
      logLevel = "info";
      enableRequestLogging = "false";
      newUserDefaultRequiresApproval = "true";
      PGID = "100";
      PUID = "1000";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "pulsarr";
      "docktail.service.port" = "3003";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "pulsarr.data:/app/data"
    ];
  };

  systemd.services.podman-pulsarr.serviceConfig.Restart = lib.mkForce "always";
}
