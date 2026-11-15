{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.service.home-assistant-mosquitto;
  mosquittoConfig = pkgs.writeText "mosquitto.conf" ''
    listener 1883 127.0.0.1
    allow_anonymous true
    persistence true
    persistence_location /mosquitto/data/
    log_dest stdout
    log_type all
  '';
in
{
  options.fleet.service.home-assistant-mosquitto.enable = lib.mkEnableOption
    "the loopback-only Mosquitto MQTT broker";

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.home-assistant-mosquitto = {
      image = "docker.io/library/eclipse-mosquitto:2.1.2-alpine@sha256:75d6662dee52c947dc9dd9c29f1d8d7ffef78ddaf38001caa09755681e8bbc98";
      networks = [ "host" ];
      volumes = [
        "${mosquittoConfig}:/mosquitto/config/mosquitto.conf:ro"
        "home-assistant-mosquitto.data:/mosquitto/data"
      ];
    };

    systemd.services.podman-home-assistant-mosquitto.serviceConfig.Restart =
      lib.mkForce "always";
  };
}
