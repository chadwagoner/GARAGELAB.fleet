{ lib, ... }:

{
  virtualisation.oci-containers.containers.ha-matter-server = {
    image = "ghcr.io/home-assistant-libs/python-matter-server:8.1@sha256:170aa093ce91c76cde4cc390918307590f0f5558fcec93f913af3cb019e6562a";
    extraOptions = [ "--security-opt=apparmor=unconfined" ];
    networks = [ "host" ];
    volumes = [
      "/run/dbus:/run/dbus:ro"
      "home-assistant-matter.data:/data"
    ];
  };

  systemd.services.podman-ha-matter-server.serviceConfig.Restart =
    lib.mkForce "always";
}
