# Fastmail Meeting Nudger on edge-6201

The service is staged but disabled until its encrypted credentials are created.
It uses `ghcr.io/chadwagoner/fastmail-meeting-nudger:2026.10.3`, publishes no
ports, and starts with `DRY_RUN=true` and `REMINDER_INCLUDE_ICS=false`.

## Create the encrypted credentials

Create a GitHub PAT (classic) with `read:packages` using an account with access
to the private image. The configured login username is `chadwagoner`; change
it if a different account owns the token. Authorize SSO if required.

From the repository root, open the encrypted registry secret:

```console
EDITOR=vim make agenix-edit AGE_FILE=github-pat.age
```

Enter **only the raw PAT**, not an environment-variable assignment. Next:

```console
EDITOR=vim make agenix-edit AGE_FILE=edge-6201-fastmail-meeting-nudger-env.age
```

Enter the application's real values in environment-file format:

```dotenv
FASTMAIL_USERNAME=you@fastmail.com
FASTMAIL_APP_PASSWORD=replace-with-fastmail-app-password
SMTP_FROM=you@fastmail.com
```

Replace these examples before saving. Use a Fastmail app password with the
calendar and mail access the application requires, not your account password.
Do not paste credentials into chat, commit plaintext, or put passwords in shell
commands. Both encrypted files have only the administrator and `edge-6201`
as recipients. The shared `github-pat.age` can be reused on other hosts later:
add their recipient keys in `secrets/agenix-rules.nix`, rekey the encrypted file,
and declare `age.secrets.github-pat` on each consuming host. Only grant hosts
access when needed; keep this token limited to package reads.
Agenix exposes root-readable runtime files, and the container
module uses the PAT for Podman login and the environment file for app secrets.
Podman's generated registry authentication is also sensitive host state.

## Enable, validate, and deploy

In `hosts/edge-6201/services.nix`, enable the staged module:

```nix
fleet.service.fastmail-meeting-nudger.enable = true;
```

Review the public settings in `services/fastmail-meeting-nudger.nix`.
The default scan is at **02:00 UTC** daily; change `TZ` and `SCHEDULE_TIME` if
needed. Empty calendar selection means all calendars. Organizer aliases and
calendar filters must match the application's documented semantics.

Ensure both new `.age` files and the service module are included in Git before
evaluating a Git-backed flake. Then run:

```console
make nix-check
make nix-eval HOST=edge-6201
```

Commit and push the configuration and ciphertext; do not deploy a branch that
lacks either secret. After CI passes, build and temporarily activate the pushed
branch (replace `my-branch`, and set `REMOTE` if SSH needs a different target):

```console
make remote-build HOST=edge-6201 REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
make remote-dry-activate HOST=edge-6201 REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
make remote-test HOST=edge-6201 REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
```

On the host:

```console
sudo systemctl status podman-fastmail-meeting-nudger.service --no-pager
sudo journalctl -u podman-fastmail-meeting-nudger.service -n 100 --no-pager
sudo podman ps --filter name=fastmail-meeting-nudger
```

Check for successful registry authentication, image pull, calendar access,
and a dry-run scan at the scheduled time. Startup alone does not establish that
calendar/SMTP credentials work. Confirm the image supports the host architecture
and its runtime user can write `/data`; adjust ownership to the image's actual
UID/GID if necessary rather than making the data directory world-writable.

After verification, use `make remote-switch` with the same `HOST` and
`REMOTE_FLAKE` arguments. Keep dry-run enabled until the intended recipients,
organizers, and calendar selection have been reviewed. Setting `DRY_RUN=false`
permits real email; enabling ICS is a separate opt-in.

## State and recovery

SQLite history lives at `/var/lib/fastmail-meeting-nudger/nudger.sqlite3` on
the host, mounted as `/data/nudger.sqlite3`. No backup policy is configured by
this service. Before production use, arrange a consistent SQLite backup (for
example, stop the service while backing up its data directory) and test restore.
Losing history can change duplicate-reminder behavior.

Disable the module and redeploy to stop the workload; its host data directory
is retained. Rotate credentials upstream if exposed, update the corresponding
encrypted file, deploy, and restart the container to load the new credentials.
