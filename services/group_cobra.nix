{ ... }:

{
  # Keep service imports explicit so adding a file does not deploy it by accident.
  imports = [
    ./service_adguard.nix
    ./service_beszel.nix
    ./service_cleanuparr.nix
    ./service_docktail.nix
    ./service_nzbget.nix
    ./service_plex.nix
    ./service_pocket-id.nix
    ./service_profilarr.nix
    ./service_prowlarr.nix
    ./service_pulsarr.nix
    ./service_radarr.nix
    ./service_sonarr.nix
  ];
}
