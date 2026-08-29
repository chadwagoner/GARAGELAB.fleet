{ lib, ... }:

{
  virtualisation.oci-containers.containers.home-assistant-matter = {
    image = "ghcr.io/matter-js/matterjs-server:1.4.0";
    networks = [ "host" ];
    volumes = [
      "/run/dbus:/run/dbus:ro"
      "home-assistant-matter.data:/data"
    ];
  };

  systemd.services.podman-home-assistant-matter.serviceConfig.Restart =
    lib.mkForce "always";
}
