{ config, lib, ... }:

let
  encryptionKeyPath = "/run/secrets/pocket-id-encryption-key";
in
{
  age.secrets.pocket-id-encryption-key = {
    file = ../secrets/pocket-id-encryption-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  virtualisation.oci-containers.containers.id = {
    image = "ghcr.io/pocket-id/pocket-id:v2.11.0";
    environment = {
      ANALYTICS_DISABLED = "true";
      APP_URL = "https://id.${config.fleet.tailscale.magicDnsSuffix}";
      ENCRYPTION_KEY_FILE = encryptionKeyPath;
      PGID = "1000";
      PUID = "1000";
      TRUST_PROXY = "true";
    };
    labels = {
      "docktail.service.enable" = "true";
      "docktail.service.name" = "id";
      "docktail.service.port" = "1411";
      "docktail.service.network" = "proxy";
      "docktail.service.protocol" = "http";
      "docktail.service.service-port" = "443";
      "docktail.service.service-protocol" = "https";
    };
    networks = [ "proxy" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "pocket-id.data:/app/data"
      "${config.age.secrets.pocket-id-encryption-key.path}:${encryptionKeyPath}:ro"
    ];
  };

  systemd.services.podman-id.serviceConfig.Restart =
    lib.mkForce "always";
}
