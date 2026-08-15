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
      image = "ghcr.io/home-assistant/home-assistant:2026.8.2@sha256:56690a89c79a0de98035e1719f8324a92d5859c1192ff45adb0230ea81cb42a5";
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
