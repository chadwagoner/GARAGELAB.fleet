{ lib, ... }:

{
  virtualisation.oci-containers.containers.signal-api = {
    image = "docker.io/bbernhard/signal-cli-rest-api:0.101@sha256:2399d449123cdad56c4d859277e3b9127e1a00c4d2ab4601c239882609286cf8";
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
