{ lib, ... }:

{
  virtualisation.oci-containers.containers.nzbget = {
    image = "ghcr.io/linuxserver/nzbget:26.3.20261009@sha256:90f08a0c260f5ba3be401d9b21f7a92975ac0fb2331bb1f456ed9f09f3ca4ddb";
    environment = {
      PGID = "100";
      PUID = "1000";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "nzbget";
      "docktail.service.port" = "6789";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "downloads:/downloads"
      "nzbget.config:/config"
    ];
  };

  systemd.services.podman-nzbget.serviceConfig.Restart = lib.mkForce "always";
}
