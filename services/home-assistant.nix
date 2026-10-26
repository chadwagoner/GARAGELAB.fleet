{ config, lib, ... }:

let
  cfg = config.fleet.service.home-assistant;
in
{
  options.fleet.service.home-assistant.docktailLabels = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Host-specific Docktail labels for Home Assistant.";
  };

  config = {
    virtualisation.oci-containers.containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:2026.10.4@sha256:23f4dfbb69ce76315dbc4de7915504f1c2dcecd7ca2648113a493a385972e133";
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      labels = cfg.docktailLabels;
      networks = [ "host" ];
      privileged = true;
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/run/dbus:/run/dbus:ro"
        "home-assistant.config:/config"
      ];
    };

    systemd.services.podman-home-assistant.serviceConfig.Restart =
      lib.mkForce "always";
  };
}
