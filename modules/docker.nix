{ config, lib, ... }:

let
  proxyContainers =
    lib.filterAttrs
      (_: container: lib.elem "proxy" container.networks)
      config.virtualisation.oci-containers.containers;
in
{
  virtualisation.docker = {
    enable = true;

    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  virtualisation.oci-containers.backend = "docker";

  systemd.services = {
    docker-network-proxy = {
      description = "Create the proxy Docker network";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        ${lib.getExe config.virtualisation.docker.package} network inspect proxy >/dev/null 2>&1 \
          || ${lib.getExe config.virtualisation.docker.package} network create --driver bridge proxy
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  }
  // lib.mapAttrs' (
    _: container:
    lib.nameValuePair container.serviceName {
      after = [ "docker-network-proxy.service" ];
      requires = [ "docker-network-proxy.service" ];
    }
  ) proxyContainers;
}
