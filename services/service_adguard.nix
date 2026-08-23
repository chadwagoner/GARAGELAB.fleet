{ lib, ... }:

{
  virtualisation.oci-containers.containers.adguard = {
    image = "adguard/adguardhome:v0.107.79@sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0";
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
