{ ... }:

{
  imports = [
    ./service_actual-budget.nix
    ./service_adguard.nix
    ./service_beszel-agent-intel.nix
    ./service_beszel.nix
    ./service_cleanuparr.nix
    ./service_docktail.nix
    ./service_homarr.nix
    ./service_home-assistant.nix
    ./service_home-assistant-matter.nix
    ./service_home-assistant-mosquitto.nix
    ./service_home-assistant-zigbee2mqtt.nix
    ./service_nzbget.nix
    ./service_plex.nix
    ./service_profilarr.nix
    ./service_prowlarr.nix
    ./service_pulsarr.nix
    ./service_radarr.nix
    ./service_sonarr.nix
    ./service_tunarr.nix
    # GAME SERVERS
    ./service_minecraft-server.nix
  ];
}
