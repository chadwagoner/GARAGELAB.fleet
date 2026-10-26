{ lib, ... }:

{
  virtualisation.oci-containers.containers.signal-api = {
    image = "docker.io/bbernhard/signal-cli-rest-api:0.101@sha256:2cf09d66a86fdd210e42ee91662216364acc27da1163a8c44167a77ea3a6559a";
    environment = {
      MODE = "native";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "signal-api";
      "docktail.service.port" = "8080";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [ "signal-api.data:/home/.local/share/signal-cli" ];
  };

  systemd.services.podman-signal-api.serviceConfig.Restart =
    lib.mkForce "always";
}
