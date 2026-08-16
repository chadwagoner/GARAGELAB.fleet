{ ... }:

{
  # Keep service imports explicit so adding a file does not deploy it by accident.
  imports = [
    ./service_adguard.nix
    ./service_beszel-agent-intel.nix
    ./service_beszel.nix
    ./service_cleanuparr.nix
    ./service_docktail.nix
    ./service_homarr.nix
    ./service_home-assistant-matter.nix
    ./service_home-assistant.nix
    ./service_nzbget.nix
    ./service_plex.nix
    # ./service_pocket-id.nix # pausing on OIDC auth for now
    ./service_profilarr.nix
    ./service_prowlarr.nix
    ./service_pulsarr.nix
    ./service_radarr.nix
    ./service_sonarr.nix
    ./service_tunarr.nix
  ];
}
