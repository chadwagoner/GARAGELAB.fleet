{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.pulsarr = {
    image = "docker.io/lakker/pulsarr:1.1.6@sha256:4830936b1d77ca321ab2d8cdbf734f5feee35c65e99b0264569df5816cb49dcc";
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
