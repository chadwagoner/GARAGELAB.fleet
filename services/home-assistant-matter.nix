{ lib, ... }:

{
  virtualisation.oci-containers.containers.home-assistant-matter = {
    image = "ghcr.io/matter-js/matterjs-server:1.6.1@sha256:5591f9f65926ca4b13b34cfd9c9888cb9d9ee9f147fe0b04c8e025cbeeee0eb7";
    networks = [ "host" ];
    volumes = [
      "/run/dbus:/run/dbus:ro"
      "home-assistant-matter.data:/data"
    ];
  };

  systemd.services.podman-home-assistant-matter.serviceConfig.Restart =
    lib.mkForce "always";
}
