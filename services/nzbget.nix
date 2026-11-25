{ lib, ... }:

{
  virtualisation.oci-containers.containers.nzbget = {
    image = "ghcr.io/linuxserver/nzbget:26.3.20261120@sha256:217c7028b9d671b34bfb60adcd09f3d6d24761226ec7025b3438eaa55fc0728e";
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
