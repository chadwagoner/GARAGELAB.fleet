{ ... }:

{
  imports = [
    ../../services/beszel-agent-intel.nix
    ../../services/fastmail-meeting-nudger.nix
    ../../services/home-assistant.nix
    ../../services/home-assistant-matter.nix
  ];

  fleet.service.fastmail-meeting-nudger.enable = true;
}
