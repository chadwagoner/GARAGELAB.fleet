{ config, lib, ... }:

let
  cfg = config.fleet.tailscale;

  providesRouting =
    cfg.advertiseRoutes != [ ]
    || cfg.advertiseExitNode;

  boolFlag = name: enabled:
    "--${name}=${lib.boolToString enabled}";
in
{
  options.fleet.tailscale = {
    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether Tailscale should configure DNS for MagicDNS and split-DNS routes.";
    };

    ssh = lib.mkEnableOption "Tailscale SSH";

    magicDnsSuffix = lib.mkOption {
      type = lib.types.strMatching "^[a-z0-9-]+[.]ts[.]net$";
      example = "example-tailnet.ts.net";
      description = "Tailscale MagicDNS suffix used to form service URLs.";
    };

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "192.168.128.0/24" ];
      description = "Subnet routes advertised through Tailscale.";
    };

    advertiseExitNode =
      lib.mkEnableOption "Tailscale exit-node advertising";
  };

  config = {
    age.secrets.tailscale-oauth = {
      file = ../secrets/tailscale-oauth.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.tailscale = {
      enable = true;

      authKeyFile = config.age.secrets.tailscale-oauth.path;

      authKeyParameters = {
        ephemeral = false;
        preauthorized = true;
      };

      extraUpFlags = [
        "--advertise-tags=tag:server"
      ];

      extraSetFlags = [
        (boolFlag "accept-dns" cfg.acceptDns)
        (boolFlag "ssh" cfg.ssh)
        (boolFlag "advertise-exit-node" cfg.advertiseExitNode)
        "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
      ];

      useRoutingFeatures =
        if providesRouting then "server" else "none";

      openFirewall = true;
    };
  };
}
