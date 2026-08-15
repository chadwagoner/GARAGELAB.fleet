{ lib, ... }:

{
  virtualisation.oci-containers.containers.satisfactory-server = {
    image = "docker.io/wolveix/satisfactory-server:v1.9.10@sha256:e103700ae6ae4c50f19dac80eadb2a805c5b885e179ae2a40850e967bf189efd";
    extraOptions = [
      "--memory=8g"
      "--memory-reservation=2g"
    ];
    hostname = "satisfactory-server";
    ports = [
      "7777:7777/tcp"
      "7777:7777/udp"
      "8888:8888/tcp"
    ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "satisfactory-server.config:/config"
    ];
  };

  systemd.services.podman-satisfactory-server.serviceConfig.Restart =
    lib.mkForce "always";
}
