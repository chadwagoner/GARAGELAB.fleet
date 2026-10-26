{ lib, ... }:

{
  virtualisation.oci-containers.containers.actual-budget = {
    image = "docker.io/actualbudget/actual-server:26.10.0@sha256:24645e971da6bb1a1f953d6859e307a0b29be1e8b4130a35b3220c209b5b860c";
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "actual";
      "docktail.service.port" = "5006";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [ "actual-budget.data:/data" ];
  };

  systemd.services.podman-actual-budget.serviceConfig.Restart =
    lib.mkForce "always";
}
