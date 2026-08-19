{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.backup.containerVolumes;
  containers = config.virtualisation.oci-containers.containers;

  volumeSource = volume:
    lib.head (lib.splitString ":" volume);

  isNamedVolume = source:
    !(lib.hasPrefix "/" source || lib.hasPrefix "." source);

  namedVolumesByContainer = lib.mapAttrs (
    _: container:
    lib.unique (
      lib.filter isNamedVolume (map volumeSource container.volumes)
    )
  ) containers;

  discoveredVolumes = lib.sort builtins.lessThan (
    lib.unique (lib.concatLists (lib.attrValues namedVolumesByContainer))
  );

  selectedVolumes = lib.filter (
    volume: !(lib.elem volume cfg.excludeVolumes)
  ) discoveredVolumes;

  selectedContainers = lib.filterAttrs (
    _: volumes: lib.any (volume: lib.elem volume selectedVolumes) volumes
  ) namedVolumesByContainer;

  selectedContainerNames = lib.attrNames selectedContainers;

  ownersOf = volume:
    lib.filter (
      name: lib.elem volume namedVolumesByContainer.${name}
    ) selectedContainerNames;

  sharedSelectedVolumes = lib.filter (
    volume: lib.length (ownersOf volume) > 1
  ) selectedVolumes;

  backupMount = lib.attrByPath [ cfg.mount ] null config.fleet.nfs.mounts;
  backupMountPoint =
    if backupMount == null then
      "/run/invalid-container-backup-mount"
    else
      backupMount.mountPoint;

  hostDirectory = "${backupMountPoint}/${config.networking.hostName}";
  repository = "${hostDirectory}/${cfg.repositoryName}";
  passwordFile =
    if cfg.passwordFile == null then
      "/run/invalid-container-backup-password"
    else
      cfg.passwordFile;

  backupUser = lib.attrByPath [ cfg.user ] null config.users.users;

  shellArray = values:
    lib.concatMapStringsSep " " lib.escapeShellArg values;

  backupCommands = lib.concatMapStringsSep "\n" (
    name:
    let
      volumes = lib.filter (
        volume: lib.elem volume selectedVolumes
      ) selectedContainers.${name};
    in
    "backup_group ${lib.escapeShellArg containers.${name}.serviceName} ${shellArray volumes}"
  ) selectedContainerNames;

  podman = lib.getExe config.virtualisation.podman.package;
  restic = lib.getExe pkgs.restic;
  sudo = "${config.security.wrapperDir}/sudo";
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  prepareScript = pkgs.writeShellApplication {
    name = "fleet-container-volume-backup-prepare";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      mount_point=${lib.escapeShellArg backupMountPoint}
      host_directory=${lib.escapeShellArg hostDirectory}

      if ! findmnt --noheadings --mountpoint "$mount_point" --types nfs,nfs4 >/dev/null; then
        echo "Refusing directory creation: $mount_point is not an active NFS mount." >&2
        exit 1
      fi

      ensure_directory() {
        local directory=$1

        if [[ -e "$directory" && ! -d "$directory" ]]; then
          echo "Required backup path exists but is not a directory: $directory" >&2
          return 1
        fi

        mkdir --parents -- "$directory"
      }

      ensure_directory "$host_directory"
    '';
  };

  backupScript = pkgs.writeShellApplication {
    name = "fleet-container-volume-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.restic
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      repository=${lib.escapeShellArg repository}
      password_file=${lib.escapeShellArg passwordFile}
      host_name=${lib.escapeShellArg config.networking.hostName}
      active_unit=""

      cleanup() {
        local status=$?
        trap - EXIT INT TERM

        if [[ -n "$active_unit" ]]; then
          if ! ${sudo} --non-interactive ${systemctl} start "$active_unit"; then
            status=1
          fi
        fi

        exit "$status"
      }

      trap cleanup EXIT
      trap 'exit 1' INT TERM

      mkdir --parents -- "$repository"

      if [[ ! -f "$repository/config" ]]; then
        ${restic} \
          --repo "$repository" \
          --password-file "$password_file" \
          init
      fi

      backup_volume() {
        local volume=$1

        if ! ${sudo} --non-interactive ${podman} volume exists "$volume"; then
          echo "Required Podman volume does not exist: $volume" >&2
          return 1
        fi

        ${restic} \
          --repo "$repository" \
          --password-file "$password_file" \
          backup \
          --host "$host_name" \
          --skip-if-unchanged \
          --tag container-volume \
          --tag "volume:$volume" \
          --stdin-filename "$volume.tar" \
          --stdin-from-command \
          -- ${sudo} --non-interactive ${podman} volume export "$volume"
      }

      backup_group() {
        local unit=$1
        local was_active=false
        local volume
        shift

        if ${systemctl} is-active --quiet "$unit"; then
          active_unit=$unit
          ${sudo} --non-interactive ${systemctl} stop "$unit"
          was_active=true
        fi

        for volume in "$@"; do
          backup_volume "$volume"
        done

        if [[ "$was_active" == true ]]; then
          ${sudo} --non-interactive ${systemctl} start "$unit"
          active_unit=""
        fi
      }

      ${backupCommands}
    '';
  };

  maintenanceScript = pkgs.writeShellApplication {
    name = "fleet-container-volume-backup-maintenance";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.restic
      pkgs.util-linux
    ];
    text = ''
      repository=${lib.escapeShellArg repository}
      password_file=${lib.escapeShellArg passwordFile}
      host_name=${lib.escapeShellArg config.networking.hostName}

      if [[ ! -f "$repository/config" ]]; then
        echo "Restic repository has not been initialized: $repository" >&2
        exit 1
      fi

      ${restic} \
        --repo "$repository" \
        --password-file "$password_file" \
        forget \
        --host "$host_name" \
        --tag container-volume \
        --keep-weekly ${toString cfg.retention.weekly} \
        --keep-monthly ${toString cfg.retention.monthly} \
        --keep-yearly ${toString cfg.retention.yearly} \
        --prune

      ${restic} \
        --repo "$repository" \
        --password-file "$password_file" \
        check
    '';
  };
in
{
  options.fleet.backup.containerVolumes = {
    enable = lib.mkEnableOption "scheduled backups of deployed Podman named volumes";

    mount = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "backup";
      description = "Name of the writable fleet.nfs.mounts entry used for backups.";
    };

    repositoryName = lib.mkOption {
      type = lib.types.strMatching "^[A-Za-z0-9][A-Za-z0-9._-]*$";
      default = "restic";
      description = "Directory name of the Restic repository below the hostname directory.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "^/.*");
      default = null;
      description = "Runtime path to the Restic repository password file.";
    };

    user = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "nix";
      description = "Local user that owns and writes the Restic repository.";
    };

    schedule = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "Sun *-*-* 03:30:00 UTC";
      description = "systemd OnCalendar expression for volume backups.";
    };

    maintenanceSchedule = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "*-*-01 05:00:00 UTC";
      description = "systemd OnCalendar expression for retention and integrity checks.";
    };

    excludeVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
      description = "Discovered named volumes intentionally excluded from backups.";
    };

    retention = {
      weekly = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8;
        description = "Number of weekly snapshots to retain per volume.";
      };

      monthly = lib.mkOption {
        type = lib.types.ints.positive;
        default = 12;
        description = "Number of monthly snapshots to retain per volume.";
      };

      yearly = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Number of yearly snapshots to retain per volume.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = backupMount != null;
        message = "fleet.backup.containerVolumes requires fleet.nfs.mounts.${cfg.mount}.";
      }
      {
        assertion = backupMount == null || !backupMount.readOnly;
        message = "fleet.backup.containerVolumes requires a writable backup mount.";
      }
      {
        assertion = cfg.passwordFile != null;
        message = "fleet.backup.containerVolumes.passwordFile must be configured.";
      }
      {
        assertion = backupUser != null;
        message = "fleet.backup.containerVolumes.user must reference an existing user.";
      }
      {
        assertion = backupUser == null || lib.elem "wheel" backupUser.extraGroups;
        message = "fleet.backup.containerVolumes.user must be in wheel for rootful Podman access.";
      }
      {
        assertion = config.security.sudo.wheelNeedsPassword == false;
        message = "fleet.backup.containerVolumes requires passwordless sudo for the backup user.";
      }
      {
        assertion = lib.all (volume: lib.elem volume discoveredVolumes) cfg.excludeVolumes;
        message = "fleet.backup.containerVolumes.excludeVolumes contains an undiscovered volume.";
      }
      {
        assertion = selectedVolumes != [ ];
        message = "fleet.backup.containerVolumes did not discover any included named volumes.";
      }
      {
        assertion = sharedSelectedVolumes == [ ];
        message = "fleet.backup.containerVolumes cannot automatically back up shared named volumes.";
      }
    ];

    environment.systemPackages = [ pkgs.restic ];

    systemd.services.fleet-container-volume-backup-prepare = {
      description = "Ensure the host backup directory exists";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = [ backupMountPoint ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        UMask = "0002";
        ExecStart = lib.getExe prepareScript;
      };
    };

    systemd.services.fleet-container-volume-backup = {
      description = "Back up deployed Podman named volumes";
      after = [
        "fleet-container-volume-backup-prepare.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "fleet-container-volume-backup-prepare.service" ];
      unitConfig.RequiresMountsFor = [ backupMountPoint ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        UMask = "0077";
        Nice = 10;
        IOSchedulingClass = "idle";
        ExecStart = lib.getExe backupScript;
      };
    };

    systemd.timers.fleet-container-volume-backup = {
      description = "Weekly Podman named-volume backup schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        Unit = "fleet-container-volume-backup.service";
      };
    };

    systemd.services.fleet-container-volume-backup-maintenance = {
      description = "Prune and verify container-volume backups";
      after = [
        "fleet-container-volume-backup-prepare.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "fleet-container-volume-backup-prepare.service" ];
      unitConfig.RequiresMountsFor = [ backupMountPoint ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        UMask = "0077";
        Nice = 10;
        IOSchedulingClass = "idle";
        ExecStart = lib.getExe maintenanceScript;
      };
    };

    systemd.timers.fleet-container-volume-backup-maintenance = {
      description = "Monthly container-volume backup maintenance schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.maintenanceSchedule;
        Persistent = true;
        Unit = "fleet-container-volume-backup-maintenance.service";
      };
    };
  };
}
