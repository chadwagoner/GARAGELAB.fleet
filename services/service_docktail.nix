{ config, lib, ... }:

{
  config = {
    age.secrets.docktail-oauth = {
      file = ../secrets/docktail-oauth.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    virtualisation.oci-containers.containers.docktail = {
      image = "ghcr.io/marvinvr/docktail:1.7.3";
      environment = {
        TAILSCALE_OAUTH_CLIENT_ID = "kYaEDocmEv11CNTRL";
      };
      environmentFiles = [
        config.age.secrets.docktail-oauth.path
      ];
      networks = [ "proxy" ];
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/run/docker.sock:/var/run/docker.sock:ro"
        "/run/tailscale:/var/run/tailscale"
      ];
    };

    systemd.services.podman-docktail.serviceConfig.Restart =
      lib.mkForce "always";
  };
}
