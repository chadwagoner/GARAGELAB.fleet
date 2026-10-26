{ ... }:

{
  imports = [
    ../../services/actual-budget.nix
    ../../services/adguard.nix
    ../../services/apprise.nix
    ../../services/beszel-agent-intel.nix
    ../../services/beszel.nix
    ../../services/cleanuparr.nix
    ../../services/docktail.nix
    ../../services/homarr.nix
    ../../services/home-assistant.nix
    ../../services/home-assistant-matter.nix
    # ../../services/home-assistant-mosquitto.nix
    # ../../services/home-assistant-zigbee2mqtt.nix
    ../../services/nzbget.nix
    ../../services/plex.nix
    ../../services/profilarr.nix
    ../../services/prowlarr.nix
    ../../services/pulsarr.nix
    ../../services/radarr.nix
    ../../services/signal-api.nix
    ../../services/sonarr.nix
    ../../services/tunarr.nix
    # GAME SERVERS
    ../../services/minecraft-server.nix
  ];
}
