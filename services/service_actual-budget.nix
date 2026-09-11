{ lib, ... }:

{
  virtualisation.oci-containers.containers.actual-budget = {
    image = "docker.io/actualbudget/actual-server:26.9.0@sha256:552beab3dec8c93d46b8b9245612d63c3f123b8a45063a474f53e229b17621d3";
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
