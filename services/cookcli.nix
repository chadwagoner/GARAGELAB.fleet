{ lib, ... }:

{
  virtualisation.oci-containers.containers.cookcli = {
    image = "ghcr.io/cooklang/cookcli:0.40.0@sha256:b3721b7bdf37d0d26c081be3b92c97700ff9fe29229ffd37ac79fa685122eb11";
    environment.COOK_CONFIG_DIR = "/config";
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
