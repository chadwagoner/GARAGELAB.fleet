{ lib, ... }:

{
  virtualisation.oci-containers.containers.satisfactory-server = {
    image = "docker.io/wolveix/satisfactory-server:v1.9.11@sha256:ac252dba41653eb21c6feed94b577f98fa152f5792b1aeff2ce11fe364355137";
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
