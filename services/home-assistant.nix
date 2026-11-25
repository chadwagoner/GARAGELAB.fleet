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
      image = "ghcr.io/home-assistant/home-assistant:2026.11.3@sha256:24e541ddae5818bf8eb27898b9ba00d0c344a655aa5097e9e9bd4b19356be847";
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
