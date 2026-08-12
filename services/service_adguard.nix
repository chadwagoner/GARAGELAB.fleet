{ lib, ... }:

{
  virtualisation.oci-containers.containers.adguard = {
    image = "adguard/adguardhome:v0.107.78";
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
