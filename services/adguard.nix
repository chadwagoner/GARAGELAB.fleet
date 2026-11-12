{ lib, ... }:

{
  virtualisation.oci-containers.containers.adguard = {
    image = "adguard/adguardhome:v0.107.80@sha256:e2e1b48c832f7705be915873f95de0d5114de573736441d7f2923a8a6293027c";
    networks = [ "host" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "adguard-config:/opt/adguardhome/conf"
      "adguard-data:/opt/adguardhome/work"
    ];
  };

  systemd.services.podman-adguard.serviceConfig.Restart =
    lib.mkForce "always";

  networking.firewall = {
    allowedTCPPorts = [
      53
      80
      3000
    ];
    allowedUDPPorts = [ 53 ];
  };
}
