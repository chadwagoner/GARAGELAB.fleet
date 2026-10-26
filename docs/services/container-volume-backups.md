# Container-volume backups

Cobra backs up the named volumes used by its deployed Podman containers to an
encrypted Restic repository on the `backup` NFS mount. The backup runs weekly
on Sunday at 09:30 UTC. Monthly maintenance applies the retention policy and
checks repository integrity.

The backup module discovers named volumes from the final
`virtualisation.oci-containers.containers` configuration. Consequently, only
services imported by `hosts/cobra/services.nix` participate. Bind mounts such
as `/srv/media`, runtime secrets, and `/etc/localtime` are not container-volume
backups. The shared `downloads` volume is explicitly excluded because it holds
replaceable transfer data.

## Safety and consistency

The NixOS configuration refuses to evaluate unless the named `backup` NFS
mount exists and is writable. At runtime, each job also verifies that the
configured destination is an active `nfs` or `nfs4` mount before creating a
directory or writing data. This prevents an unavailable NAS from redirecting
backup data onto Cobra's root filesystem.

Before exporting data, the job records whether each owning container service
is running and stops it. This gives SQLite databases and multi-file application
state a consistent point-in-time backup. The job restarts each previously active
service before moving to the next one and attempts recovery on failure. A
restart can itself fail: after a failed backup, inspect the owning container
service as well as the backup unit. Services that were already inactive are
left inactive.

The preparation unit safely creates this hierarchy after verifying the NFS
mount:

```text
/srv/backup/<hostname>/
```

It uses `mkdir -p` behavior as the `nix` user. If the hostname directory is
already present, the unit does not remove its contents or change its ownership
or permissions. If a required path exists as something other than a directory,
the unit fails rather than replacing it. The Restic repository is initialized
automatically at:

```text
/srv/backup/cobra/restic
```

Its password is decrypted at runtime from
`secrets/cobra-container-backup-restic-password.age`. The secret is owned by
the `nix` user and is not written into the Nix store or backup repository.
Do not replace this payload as an ordinary secret rotation: add and verify a
new Restic repository key before removing the old key. Losing every valid key
makes the encrypted backups unrecoverable.

## Schedule and retention

- Backup: Sunday at 09:30 UTC
- Maintenance: the first day of each month at 05:00 UTC
- Retention: 8 weekly, 12 monthly, and 3 yearly snapshots per volume

Both systemd timers are persistent. If Cobra is offline at a scheduled time,
systemd runs the missed job after the next boot.

## Operate and verify

Run a backup immediately from the administrator workstation:

```console
make remote-backup
```

Create or verify the hostname directory without running a backup:

```console
make remote-backup-prepare
```

Inspect the schedules and recent backup logs:

```console
make remote-backup-status
```

List every container-volume snapshot, or only snapshots for one named volume:

```console
make remote-backup-list
make remote-backup-list VOLUME=home-assistant.config
```

List the files stored in the latest snapshot for a volume. Specify a snapshot
ID only when inspecting an older version:

```console
make remote-backup-files VOLUME=home-assistant.config
make remote-backup-files VOLUME=home-assistant.config SNAPSHOT=SNAPSHOT_ID
```

Run the same repository integrity check used by monthly maintenance. The full
data variant reads every stored pack and can take substantially longer:

```console
make remote-backup-check
make remote-backup-check-data
```

Run retention, pruning, and the regular integrity check immediately:

```console
make remote-backup-maintenance
```

On Cobra, inspect both units directly when troubleshooting:

```console
sudo systemctl status fleet-container-volume-backup.service --no-pager
systemctl list-timers 'fleet-container-volume-backup*' --all --no-pager
sudo journalctl -u fleet-container-volume-backup.service -n 100 --no-pager
```

## Download a backup

Snapshots contain one Podman volume export named `<volume>.tar`. Restic can
select the latest snapshot carrying that volume's tag, so downloading the
newest backup does not require looking up its snapshot ID first:

```console
make remote-backup-download \
  VOLUME=home-assistant.config \
  OUTPUT=home-assistant.config.tar
```

To download an older version, list the volume's snapshot history and pass the
chosen ID explicitly:

```console
make remote-backup-list VOLUME=home-assistant.config
make remote-backup-download \
  VOLUME=home-assistant.config \
  SNAPSHOT=SNAPSHOT_ID \
  OUTPUT=home-assistant.config-old.tar
```

The download target writes through an `OUTPUT.partial` file and refuses to
overwrite either an existing output or partial file. Inspect the downloaded
archive locally without extracting it:

```console
tar -tvf home-assistant.config.tar
```

The tar file is the decrypted volume export. Protect or remove local downloads
when they are no longer needed; Restic encryption only protects data while it
remains inside the repository.

## Automated recovery check

CI runs the `container-backup` NixOS VM check using the generated backup script,
real Restic, and real Podman volumes. On an `x86_64-linux` machine with KVM
available, run it with:

```console
nix build --no-link --print-build-logs .#checks.x86_64-linux.container-backup
```

The check restores fixture data into a fresh volume and verifies contents,
permissions, and a symlink. It also injects stop, export, and transient restart
failures, checks that errors propagate and previously active services recover,
and verifies that inactive services remain inactive. It uses disposable VM
storage and a public test password, not production volumes or credentials.

The check bypasses NFS preparation and invokes the backup script as root with
an instrumented privilege wrapper. It does not establish production NFS access,
backup-user permissions, or application-level recoverability. Continue periodic
restores from the actual backup repository as described below.

## Test a restore

Use both checks below: the CI test exercises the script in isolation; a restore
from Cobra's repository exercises the real storage and credentials. Neither
requires replacing a production volume. Do not inject failures on Cobra.

### 1. Verify the automated test in GitHub Actions (from your Mac)

1. Commit and push the changes on your working branch, including
   `tests/container-backup.nix`. Open or update a pull request. The workflow runs
   on pull requests and pushes to `main`, not arbitrary branch pushes alone.
2. Open the pull request's **Checks**, then **NixOS CI** → **Discover NixOS
   hosts** → **Test container backup and restore**.
3. Confirm that step succeeds, not just **Evaluate flake**. The latter does not
   execute the VM. The aggregate **NixOS configurations** check must also pass.
4. If the VM test fails, save the step's log and fix that failure before treating
   the automated recovery coverage as established. KVM/build-environment errors
   are not successful backup tests.

Your Apple Silicon Mac can evaluate the Linux check but cannot execute this
KVM-based VM test locally. GitHub Actions is the recommended execution path;
the Linux command in the preceding section is an alternative, not an additional
required production-host operation. No deployment is needed for the CI test.

### 2. Check Cobra's backup job (from your Mac)

Prerequisites: SSH to `cobra` works, the backup module is already deployed, the
NAS is available, and you have sufficient free backup and local Podman storage.
These commands operate the currently deployed configuration, not your local
working tree. If your SSH alias differs, append `REMOTE=user@host` to each
`make` command, keeping `HOST=cobra`.

Choose a maintenance window: running a backup briefly stops each included
container in turn. First record the current service states:

```console
make remote-container-services
make remote-backup-prepare
make remote-backup
make remote-backup-status
make remote-container-services
make remote-backup-check
make remote-backup-list VOLUME=home-assistant.config
```

Stop on an error rather than continuing through the checklist. Expected results:

- Preparation and backup commands exit successfully.
- Backup logs show successful completion. A successful oneshot backup unit can
  be `inactive (dead)` afterward; that alone is not a failure.
- Containers that were running before the backup are running afterward.
- Restic integrity checking reports no errors.
- The volume has a snapshot. An unchanged volume may reuse an older snapshot
  because backups use `--skip-if-unchanged`.

For a direct service result and logs, run on Cobra:

```console
sudo systemctl show fleet-container-volume-backup.service -p Result -p ExecMainStatus
sudo journalctl -u fleet-container-volume-backup.service -n 100 --no-pager
```

Expect `Result=success` and `ExecMainStatus=0` after the completed run. If backup
or restart fails, inspect the owning service too; do not assume that backup
failure recovery always succeeds.

Optionally run `make remote-backup-check-data` from your Mac to read all stored
data. It can generate substantial NAS traffic. Do not run
`remote-backup-maintenance` just to test a restore: it applies retention and
prunes data.

### 3. Restore one real snapshot into a new volume (on Cobra)

Connect from your Mac:

```console
ssh cobra
bash
```

In that Bash session, list snapshots and copy the ID you intend to test:

```console
sudo -u nix restic \
  --repo /srv/backup/cobra/restic \
  --password-file /run/agenix/cobra-container-backup-restic-password \
  snapshots --tag volume:home-assistant.config
```

Replace `PASTE_SNAPSHOT_ID` below with that ID. Keep this shell open until
cleanup so the test-volume variable remains available. The block refuses to
reuse an existing volume and stops if either side of the restore pipeline fails:

```console
set -euo pipefail
SNAPSHOT_ID=PASTE_SNAPSHOT_ID
test "$SNAPSHOT_ID" != PASTE_SNAPSHOT_ID
TEST_VOLUME="restore-test-home-assistant-$(date -u +%Y%m%dT%H%M%SZ)"
if sudo podman volume exists "$TEST_VOLUME"; then
  printf 'Refusing to reuse existing volume: %s\n' "$TEST_VOLUME" >&2
  exit 1
fi
sudo podman volume create "$TEST_VOLUME"
sudo -u nix restic \
  --repo /srv/backup/cobra/restic \
  --password-file /run/agenix/cobra-container-backup-restic-password \
  dump --tag volume:home-assistant.config "$SNAPSHOT_ID" home-assistant.config.tar | \
  sudo podman volume import "$TEST_VOLUME" -
RESTORED_PATH=$(sudo podman volume inspect "$TEST_VOLUME" --format '{{.Mountpoint}}')
sudo test -s "$RESTORED_PATH/configuration.yaml"
sudo stat "$RESTORED_PATH/configuration.yaml"
sudo find "$RESTORED_PATH" -maxdepth 1 -mindepth 1 -printf '%f\n'
printf 'Restored snapshot %s into %s\n' "$SNAPSHOT_ID" "$TEST_VOLUME"
```

Success means the import exits zero, `configuration.yaml` exists and is
nonempty, and the file listing contains the expected configuration for the
chosen snapshot. Inspect additional known files as needed without posting
configuration contents or credentials in logs. This proves archive retrieval
and import, not that Home Assistant can start or every database is healthy.
Application startup testing needs a separate isolated environment; do not
attach this restored volume to the running production container.

### 4. Clean up and record the outcome

In the same Cobra shell, remove only the test volume created above:

```console
case "$TEST_VOLUME" in
  restore-test-home-assistant-*) sudo podman volume rm "$TEST_VOLUME" ;;
  *) printf 'Unexpected test-volume name; refusing cleanup\n' >&2; exit 1 ;;
esac
```

If a step failed and the Bash session exited, the temporary volume may remain.
List candidates with `sudo podman volume ls --filter name=restore-test-home-assistant-`,
verify the exact name from your test output, and remove only that volume. Never
use a blanket volume-prune command for cleanup. Restored volumes contain
decrypted application data and should not be left behind unnecessarily.

Record the date, CI run/commit, selected snapshot ID, backup service result,
Restic check result, restored-file checks, and cleanup result. Repeat periodically
and after backup-script, storage, or credential changes. Do not rotate the Restic
password as part of this exercise.

Restoring over a production volume is deliberately outside this checklist. It
requires a separate maintenance window, a stopped owning container, and an
empty replacement volume because `podman volume import` merges archive contents
into an existing volume.

## Add or exclude a volume

New named volumes from deployed services are backed up automatically. Add only
intentionally disposable volumes to `excludeVolumes` in Cobra's host
configuration. The module asserts that every exclusion names a discovered
volume, which catches stale entries and spelling mistakes during evaluation.
It also rejects automatically backing up a volume shared by multiple
containers; classify that volume explicitly or add an application-aware backup
workflow first.

If a future service needs an application-native database dump rather than a
stopped-volume export, add that workflow explicitly instead of treating a live
database copy as consistent.
