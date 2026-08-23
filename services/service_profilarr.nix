{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.profilarr = {
    image = "ghcr.io/dictionarry-hub/profilarr:2.2.0@sha256:ddcdd0f340043c2ec0a85ca74b9a6be9be42b1c0288c75fc36a26a43f695860b";
    environment = {
      PGID = "100";
      PUID = "1000";
      ORIGIN = "https://profilarr.${config.fleet.tailscale.magicDnsSuffix}";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "profilarr";
      "docktail.service.port" = "6868";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "profilarr.config:/config"
    ];
  };

  systemd.services.podman-profilarr.serviceConfig.Restart = lib.mkForce "always";
}
