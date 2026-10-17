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
      image = "ghcr.io/marvinvr/docktail:1.8.5@sha256:8bab5ebf28e7247a8153752cf116cdd8aa284a3bf5902efafed17975cb2a2203";
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
