{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.maintainerr = {
    image = "ghcr.io/maintainerr/maintainerr:3.32.0@sha256:5dcd5bef9d49c614bb74453df3da198afc05a38d8e2cd96b3669bc2c76a94112";
    environment = {
      TZ = config.time.timeZone;
      TELEMETRY = "off";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "maintainerr";
      "docktail.service.port" = "6246";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    # The upstream image runs as UID/GID 1000 and requires writable data.
    volumes = [ "maintainerr.data:/opt/data:U" ];
  };

  systemd.services.podman-maintainerr.serviceConfig.Restart =
    lib.mkForce "always";
}
