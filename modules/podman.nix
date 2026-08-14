{ config, lib, ... }:

let
  proxyContainers =
    lib.filterAttrs
      (_: container: lib.elem "proxy" container.networks)
      config.virtualisation.oci-containers.containers;
in
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;

    autoPrune = {
      enable = true;
      dates = "weekly";
    };

    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers.backend = "podman";

  virtualisation.containers.containersConf.settings.network.dns_bind_port = 1153;

  systemd.services = {
    podman-network-proxy = {
      description = "Create the proxy Podman network";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe config.virtualisation.podman.package} network create --driver bridge --ignore proxy";
      };
    };
  }
  // lib.mapAttrs' (
    _: container:
    lib.nameValuePair container.serviceName {
      after = [ "podman-network-proxy.service" ];
      requires = [ "podman-network-proxy.service" ];
    }
  ) proxyContainers;
}
