{ lib, ... }:

{
  virtualisation.oci-containers.containers.actual-budget = {
    image = "docker.io/actualbudget/actual-server:26.8.1@sha256:6478d9ddfc0924479c09e6699c205e354c6f2216dfe7de3c0fb7b590d6edcdc5";
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
