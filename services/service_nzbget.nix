{ lib, ... }:

{
  virtualisation.oci-containers.containers.nzbget = {
    image = "ghcr.io/linuxserver/nzbget:26.3.20260904@sha256:4cc4afc944e0239037b7b95c64deb8e39e49ca770b7e2f61476a04443d7fcab9";
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
