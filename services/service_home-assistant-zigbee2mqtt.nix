{ config, lib, ... }:

let
  cfg = config.fleet.service.home-assistant-zigbee2mqtt;
in
{
  options.fleet.service.home-assistant-zigbee2mqtt = {
    enable = lib.mkEnableOption "the Zigbee2MQTT bridge";

    serialDevice = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "^/dev/serial/by-id/.+$");
      default = null;
      description = "Stable host path to the Zigbee coordinator serial device.";
    };

    adapter = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional Zigbee2MQTT adapter override.";
    };

    frontend = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "the Zigbee2MQTT frontend";

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Address on which the Zigbee2MQTT frontend listens.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "TCP port for the Zigbee2MQTT frontend.";
          };

          authTokenFile = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "^/.*");
            default = null;
            description = "Runtime file containing the frontend authentication token environment variable.";
          };
        };
      };
      default = { };
      description = "Zigbee2MQTT frontend settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.fleet.service.home-assistant-mosquitto.enable;
        message = "fleet.service.home-assistant-zigbee2mqtt requires fleet.service.home-assistant-mosquitto.enable.";
      }
      {
        assertion = cfg.serialDevice != null;
        message = "fleet.service.home-assistant-zigbee2mqtt requires serialDevice to be set.";
      }
      {
        assertion = !cfg.frontend.enable || cfg.frontend.authTokenFile != null;
        message = "fleet.service.home-assistant-zigbee2mqtt.frontend requires authTokenFile when enabled.";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.optional
      (cfg.frontend.enable && cfg.frontend.host == "0.0.0.0")
      cfg.frontend.port;

    virtualisation.oci-containers.containers.home-assistant-zigbee2mqtt = {
      image = "ghcr.io/koenkk/zigbee2mqtt:2.14.0@sha256:c13d177dd7f7f396574ab00926188ad542cfb68c6a5d5f84021bebd9adf6ede9";
      devices = lib.optional
        (cfg.serialDevice != null)
        "${cfg.serialDevice}:/dev/ttyACM0";
      environment = {
        ZIGBEE2MQTT_CONFIG_FRONTEND_ENABLED = lib.boolToString cfg.frontend.enable;
        ZIGBEE2MQTT_CONFIG_FRONTEND_HOST = cfg.frontend.host;
        ZIGBEE2MQTT_CONFIG_FRONTEND_PORT = toString cfg.frontend.port;
        ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED = "true";
        ZIGBEE2MQTT_CONFIG_MQTT_SERVER = "mqtt://127.0.0.1:1883";
        ZIGBEE2MQTT_CONFIG_SERIAL_PORT = "/dev/ttyACM0";
      } // lib.optionalAttrs (cfg.adapter != null) {
        ZIGBEE2MQTT_CONFIG_SERIAL_ADAPTER = cfg.adapter;
      };
      environmentFiles = lib.optional
        (cfg.frontend.authTokenFile != null)
        cfg.frontend.authTokenFile;
      networks = [ "host" ];
      volumes = [
        "/run/udev:/run/udev:ro"
        "home-assistant-zigbee2mqtt.data:/app/data"
      ];
    };

    systemd.services.podman-home-assistant-zigbee2mqtt = {
      after = [ "podman-home-assistant-mosquitto.service" ];
      requires = [ "podman-home-assistant-mosquitto.service" ];
      serviceConfig.Restart = lib.mkForce "always";
    };
  };
}
