{ pkgs }:

pkgs.testers.runNixOSTest {
  name = "container-volume-backup";

  nodes.machine = { lib, ... }: {
    imports = [ ../modules/nfs.nix ../modules/container-backup.nix ];
    networking.hostName = "backup-test";
    virtualisation.podman.enable = true;
    virtualisation.oci-containers = {
      backend = "podman";
      containers.fixture = {
        image = "unused-test-image";
        serviceName = "fixture";
        volumes = [ "fixture:/data" ];
      };
    };
    # No image pulls: the owning service is a real, local systemd service.
    systemd.services.fixture = lib.mkForce {
      serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };
    users.users.backup = { isNormalUser = true; extraGroups = [ "wheel" ]; };
    security.sudo.wheelNeedsPassword = false;
    fleet.nfs.mounts.backup = {
      server = "unused.invalid";
      export = "/unused";
      mountPoint = "/var/lib/backup-test";
    };
    # The script is invoked directly: no NFS, timers, or prepare service.
    fileSystems."/var/lib/backup-test" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
    };
    fleet.backup.containerVolumes = {
      enable = true;
      user = "backup";
      passwordFile = "/run/test-password";
    };
    systemd.timers.fleet-container-volume-backup.wantedBy = lib.mkForce [ ];
    systemd.timers.fleet-container-volume-backup-maintenance.wantedBy = lib.mkForce [ ];
    environment.systemPackages = [ pkgs.restic pkgs.gnutar ];
    virtualisation.diskSize = 2048;
  };

  testScript = { nodes, ... }: let
    script = nodes.machine.systemd.services.fleet-container-volume-backup.serviceConfig.ExecStart;
    sudo = pkgs.writeShellScript "backup-test-sudo" ''
      set -eu
      shift # --non-interactive
      printf '%s\n' "$*" >> /run/backup-calls
      case "$*" in
        *"systemctl stop fixture")
          if test -e /run/fail-stop; then
            "$@"
            exit 41
          fi ;;
        *"systemctl start fixture")
          if test -e /run/fail-start; then
            rm /run/fail-start
            exit 42
          fi ;;
        *"podman volume export fixture")
          if test -e /run/fail-export; then exit 43; fi ;;
      esac
      exec "$@"
    '';
  in ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("printf 'public-test-password\\n' > /run/test-password")
    # Interpose only privileged calls; Restic, Podman, systemd, and the
    # generated production script remain real. No production credentials.
    machine.succeed("rm /run/wrappers/bin/sudo; cp ${sudo} /run/wrappers/bin/sudo; chmod 755 /run/wrappers/bin/sudo")
    machine.succeed("podman volume create fixture; podman volume create restored")
    machine.succeed("mkdir -p /run/fixture/nested; printf 'fixture contents\\n' > /run/fixture/nested/data; chmod 640 /run/fixture/nested/data; ln -s nested/data /run/fixture/link; tar -C /run/fixture -cf /run/fixture.tar .; podman volume import fixture /run/fixture.tar")

    def run_backup(success):
        machine.succeed(": > /run/backup-calls")
        if success:
            machine.succeed("${script}")
        else:
            machine.fail("${script}")

    def active():
        machine.succeed("systemctl is-active --quiet fixture")

    with subtest("real archive round-trip into a fresh Podman volume"):
        machine.succeed("systemctl start fixture")
        run_backup(True)
        active()
        machine.succeed("restic -r /var/lib/backup-test/backup-test/restic --password-file /run/test-password check")
        machine.succeed("restic -r /var/lib/backup-test/backup-test/restic --password-file /run/test-password dump latest fixture.tar > /run/restored.tar; podman volume import restored /run/restored.tar")
        machine.succeed("restored=$(podman volume inspect restored --format '{{.Mountpoint}}'); diff -r /run/fixture \"$restored\"; test $(stat -c %a \"$restored/nested/data\") = 640; test $(readlink \"$restored/link\") = nested/data")

    for failure in ["stop", "export", "start"]:
        with subtest(f"{failure} failure propagates and recovers owning service"):
            machine.succeed(f"touch /run/fail-{failure}")
            run_backup(False)
            active()
            machine.succeed("grep -q 'systemctl start fixture' /run/backup-calls")
            if failure == "stop":
                machine.fail("grep -q 'podman volume export' /run/backup-calls")
            if failure == "start":
                machine.succeed("test $(grep -c 'systemctl start fixture' /run/backup-calls) = 2")
            machine.succeed(f"rm -f /run/fail-{failure}")

    with subtest("initially inactive owner remains inactive on success and failure"):
        machine.succeed("systemctl stop fixture")
        for fail in [False, True]:
            if fail:
                machine.succeed("touch /run/fail-export")
            run_backup(not fail)
            machine.fail("systemctl is-active --quiet fixture")
            machine.fail("grep -E 'systemctl (start|stop) fixture' /run/backup-calls")
            machine.succeed("rm -f /run/fail-export")
  '';
}
