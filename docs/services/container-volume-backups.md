# Container-volume backups

Cobra backs up the named volumes used by its deployed Podman containers to an
encrypted Restic repository on the `backup` NFS mount. The backup runs weekly
on Sunday at 09:30 UTC. Monthly maintenance applies the retention policy and
checks repository integrity.

The backup module discovers named volumes from the final
`virtualisation.oci-containers.containers` configuration. Consequently, only
services imported by `services/group_cobra.nix` participate. Bind mounts such
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
state a consistent point-in-time backup. Each service is restarted before the
job moves to the next service, including when an export fails, which keeps
downtime localized.

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

## Test a restore

A successful unit is not a complete restore test. Periodically restore a
snapshot into a newly created temporary Podman volume. First list snapshots as
from the administrator workstation:

```console
make remote-backup-list VOLUME=home-assistant.config
```

Then, on Cobra, restore the selected archive into a new test volume:

```console
sudo -u nix restic \
  --repo /srv/backup/cobra/restic \
  --password-file /run/agenix/cobra-container-backup-restic-password \
  snapshots --tag volume:home-assistant.config
```

Create an empty test volume, then import the selected snapshot's tar stream:

```console
sudo podman volume create restore-test-home-assistant
sudo -u nix restic \
  --repo /srv/backup/cobra/restic \
  --password-file /run/agenix/cobra-container-backup-restic-password \
  dump SNAPSHOT_ID home-assistant.config.tar | \
  sudo podman volume import restore-test-home-assistant -
```

Inspect the restored volume before removing that specifically named test
volume. Restoring over a production volume requires a separate maintenance
window, a stopped owning container, and an empty replacement volume because
`podman volume import` merges archive contents into an existing volume.

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
