{ config, lib, ... }:

{
  virtualisation.oci-containers.containers.cookcli = {
    image = "ghcr.io/cooklang/cookcli:0.41.1@sha256:c6bed1fae7ff3351e2bdea26efa953dc239964d72869cfb7fb367c3a93e48cf9";
    environment = {
      COOK_CONFIG_DIR = "/config";
      COOK_CORS_ORIGIN = "https://cook.${config.fleet.tailscale.magicDnsSuffix},http://cook.${config.fleet.tailscale.magicDnsSuffix}";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "cook";
      "docktail.service.port" = "9080";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    # The upstream image runs as UID/GID 1000 and requires writable recipes.
    volumes = [
      "cookcli.recipes:/recipes:U"
      "cookcli.config:/config:U"
    ];
  };

  systemd.services.podman-cookcli.serviceConfig.Restart =
    lib.mkForce "always";
}
