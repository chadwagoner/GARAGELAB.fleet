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
      image = "ghcr.io/home-assistant/home-assistant:2026.9.3@sha256:d8922685169707fd91e8b9729902d975f06157d005e422874d201e0261dda196";
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
