{ config, lib, ... }:

let
  cfg = config.fleet.service.docktail;
in
{
  options.fleet.service.docktail.ignoredServiceNames = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Service names that Docktail should ignore when discovering services.";
  };

  config = {
    age.secrets.docktail-oauth = {
      file = ../secrets/docktail-oauth.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    virtualisation.oci-containers.containers.docktail = {
      image = "ghcr.io/marvinvr/docktail:1.8.6@sha256:a9d68198e97a9e0a90255ac3bf04390543bb3b387fc91344f07e2187409377e4";
      environment = {
        TAILSCALE_OAUTH_CLIENT_ID = "kYaEDocmEv11CNTRL";
      } // lib.optionalAttrs (cfg.ignoredServiceNames != [ ]) {
        IGNORE_SERVICE_NAMES = lib.concatStringsSep "," cfg.ignoredServiceNames;
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

    systemd.services.podman-docktail = {
      after = [
        "tailscaled-autoconnect.service"
        "tailscaled-set.service"
      ];
      wants = [
        "tailscaled-autoconnect.service"
        "tailscaled-set.service"
      ];
      serviceConfig.Restart = lib.mkForce "always";
    };
  };
}
