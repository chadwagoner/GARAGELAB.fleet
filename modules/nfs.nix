{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.nfs;

  relativePathType = lib.types.addCheck lib.types.nonEmptyStr (
    path:
    !lib.hasPrefix "/" path
    && lib.all (
      component: component != "" && component != "." && component != ".."
    ) (lib.splitString "/" path)
  );

  directoryType = lib.types.submodule {
    options = {
      relativePath = lib.mkOption {
        type = relativePathType;
        description = "Directory path relative to the NFS mount point.";
        example = "cobra";
      };

      user = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Local user that creates and owns the directory.";
        example = "nix";
      };

      mode = lib.mkOption {
        type = lib.types.strMatching "0[0-7]{3}";
        default = "0775";
        description = "Directory permissions in octal notation.";
      };
    };
  };

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

      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.nonEmptyStr;
        default = [ ];
        description = "Additional NFS mount options.";
        example = [ "nfsvers=4.2" ];
      };

      ensureDirectories = lib.mkOption {
        type = lib.types.listOf directoryType;
        default = [ ];
        description = "Directories to create after verifying the NFS mount.";
      };
    };
  });

  mountPoints = lib.mapAttrsToList (_: mount: mount.mountPoint) cfg.mounts;

  directoryServices = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        mountName: mount:
        lib.imap0 (
          index: directory:
          lib.nameValuePair "fleet-nfs-${mountName}-directory-${toString index}" {
            description = "Ensure ${mount.mountPoint}/${directory.relativePath} exists";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];

            unitConfig.RequiresMountsFor = [ mount.mountPoint ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = directory.user;
            };

            script = ''
              mount_point=${lib.escapeShellArg mount.mountPoint}
              target=${lib.escapeShellArg "${mount.mountPoint}/${directory.relativePath}"}

              ${pkgs.coreutils}/bin/stat -- "$mount_point/." >/dev/null

              fs_type="$(${pkgs.util-linux}/bin/findmnt --noheadings --raw --output FSTYPE --target "$mount_point/.")"
              case "$fs_type" in
                nfs|nfs4) ;;
                *)
                  echo "$mount_point is not an active NFS mount" >&2
                  exit 1
                  ;;
              esac

              ${pkgs.coreutils}/bin/install -d -m ${lib.escapeShellArg directory.mode} -- "$target"
            '';
          }
        ) mount.ensureDirectories
      ) cfg.mounts
    )
  );
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
      {
        assertion = lib.all (
          mount:
          lib.all (
            directory: builtins.hasAttr directory.user config.users.users
          ) mount.ensureDirectories
        ) (lib.attrValues cfg.mounts);
        message = "fleet.nfs.mounts ensureDirectories must reference declared users.";
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
          "x-systemd.idle-timeout=10min"
        ]
        ++ lib.optional mount.readOnly "ro"
        ++ mount.extraOptions;
      }
    ) cfg.mounts;

    systemd.services = directoryServices;
  };
}
