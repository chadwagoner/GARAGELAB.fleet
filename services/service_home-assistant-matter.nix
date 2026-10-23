{ lib, ... }:

{
  virtualisation.oci-containers.containers.home-assistant-matter = {
    image = "ghcr.io/matter-js/matterjs-server:1.5.4@sha256:b7f4f6c888ece6214a0720ab68c3a46654c71c6d34d01ef1850095d210c0615b";
    networks = [ "host" ];
    volumes = [
      "/run/dbus:/run/dbus:ro"
      "home-assistant-matter.data:/data"
    ];
  };

  systemd.services.podman-home-assistant-matter.serviceConfig.Restart =
    lib.mkForce "always";
}
