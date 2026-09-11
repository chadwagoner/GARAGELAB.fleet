{ lib, ... }:

{
  virtualisation.oci-containers.containers.home-assistant-matter = {
    image = "ghcr.io/matter-js/matterjs-server:1.4.0@sha256:54232d0d3e7dff5a54759469d2753399270412b4c30c55b31750a4595e4cb236";
    networks = [ "host" ];
    volumes = [
      "/run/dbus:/run/dbus:ro"
      "home-assistant-matter.data:/data"
    ];
  };

  systemd.services.podman-home-assistant-matter.serviceConfig.Restart =
    lib.mkForce "always";
}
