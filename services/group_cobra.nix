{ ... }:

{
  # Keep service imports explicit so adding a file does not deploy it by accident.
  imports = [
    ./service_adguard.nix
    ./service_docktail.nix
    ./service_plex.nix
    ./service_pocket-id.nix
  ];
}
