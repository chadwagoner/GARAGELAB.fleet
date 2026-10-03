{ config, lib, ... }:

let
  cfg = config.fleet.service.homarr;
  encryptionKeyPath = "/run/secrets/homarr-encryption-key";
in
{
  options.fleet.service.homarr.encryptionKeyFile = lib.mkOption {
    type = lib.types.strMatching "^/.*";
    description = "Runtime path to the Homarr encryption key.";
  };

  config = {
    virtualisation.oci-containers.containers.homarr = {
      image = "ghcr.io/homarr-labs/homarr:v2.0.0@sha256:3eeef80bfc58f6588844e9405da47550f681006d3019005a34f9388b5c00eb73";
      environment = {
        AUTH_PROVIDERS = "credentials";
        BASE_URL = "https://homarr.${config.fleet.tailscale.magicDnsSuffix}";
        DEFAULT_COLOR_SCHEME = "dark";
        DISABLE_ANALYTICS = "true";
        SECRET_ENCRYPTION_KEY_FILE = encryptionKeyPath;
      };
      labels = {
        "docktail.service.enable" = "true";
        "docktail.service.name" = "homarr";
        "docktail.service.port" = "7575";
        "docktail.service.network" = "proxy";
        "docktail.service.protocol" = "http";
        "docktail.service.service-port" = "443";
        "docktail.service.service-protocol" = "https";
      };
      networks = [ "proxy" ];
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/run/docker.sock:/var/run/docker.sock"
        "homarr.data:/appdata"
        "${cfg.encryptionKeyFile}:${encryptionKeyPath}:ro"
      ];
    };

    systemd.services.podman-homarr = {
      after = [ "podman.socket" ];
      requires = [ "podman.socket" ];
      serviceConfig.Restart = lib.mkForce "always";
    };
  };
}
