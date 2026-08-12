{ config, lib, ... }:

let
  cfg = config.fleet.nfs;

  mountType = lib.types.submodule ({ name, ... }: {
    options = {
      server = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "DNS name or IP address of the NFS server.";
      };

      export = lib.mkOption {
        type = lib.types.strMatching "^/.*";
        description = "Absolute path exported by the NFS server.";
        example = "/media";
      };

      mountPoint = lib.mkOption {
        type = lib.types.strMatching "^/.*";
        description = "Absolute local path where the export is mounted.";
        example = "/srv/${name}";
      };

      readOnly = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount the export read-only.";
      };

      idleTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = "10min";
        description = ''
          How long an inactive automounted export remains mounted. Set to null
          to keep the export mounted after its first access.
        '';
      };

      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.nonEmptyStr;
        default = [ ];
        description = "Additional NFS mount options.";
        example = [ "nfsvers=4.2" ];
      };
    };
  });

  mountPoints = lib.mapAttrsToList (_: mount: mount.mountPoint) cfg.mounts;
in
{
  options.fleet.nfs.mounts = lib.mkOption {
    type = lib.types.attrsOf mountType;
    default = { };
    description = "Declarative NFS client mounts for this host.";
  };

  config = lib.mkIf (lib.attrNames cfg.mounts != [ ]) {
    assertions = [
      {
        assertion = lib.length mountPoints == lib.length (lib.unique mountPoints);
        message = "fleet.nfs.mounts must use unique mount points.";
      }
    ];

    boot.supportedFilesystems = [ "nfs" ];

    fileSystems = lib.mapAttrs' (
      _: mount:
      lib.nameValuePair mount.mountPoint {
        device = "${mount.server}:${mount.export}";
        fsType = "nfs";
        options = [
          "_netdev"
          "hard"
          "noatime"
          "noauto"
          "x-systemd.automount"
        ]
        ++ lib.optional (mount.idleTimeout != null) "x-systemd.idle-timeout=${mount.idleTimeout}"
        ++ lib.optional mount.readOnly "ro"
        ++ mount.extraOptions;
      }
    ) cfg.mounts;
  };
}
