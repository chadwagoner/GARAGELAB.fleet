# Manage and rotate Agenix secrets

This repository stores encrypted Agenix payloads in [`secrets/`](../secrets/).
The recipient policy in [`secrets/secrets.nix`](../secrets/secrets.nix) grants
decryption to two public identities:

- `admin`: the administrator/recovery SSH key used to edit or rekey secrets
- `cobra`: `/etc/ssh/ssh_host_ed25519_key.pub` on the NixOS host

Private keys and decrypted values must remain outside Git. During activation,
Agenix decrypts the selected files into root-owned runtime paths under
`/run/agenix`.

## Prerequisites

Run secret-management commands from a trusted administrator workstation with:

- Nix flakes available
- a private SSH key matching the `admin` recipient
- a clean or understood Git worktree
- a secure editor that does not persist swap, backup, or cloud-synced copies

Confirm which public key a private identity produces before editing:

```console
ssh-keygen -y -f ~/.ssh/id_ed25519
```

Compare it with the `admin` value in `secrets/secrets.nix`. If the matching
private key is elsewhere, pass that path explicitly to Agenix rather than
changing the recipient policy casually.

## Edit or rotate one secret

The Make target changes into `secrets/`, so `AGE_FILE` is relative to that
directory:

```console
EDITOR=vim make agenix-edit AGE_FILE=cobra-beszel-agent.age
```

Replace the editor command if needed. Enter only the payload expected by the
consumer. For the Beszel agent, the file contains the raw token—not
`TOKEN=...`, quotes, or surrounding documentation.

If Agenix does not find the correct identity automatically, run it directly:

```console
cd secrets
EDITOR=vim nix run github:ryantm/agenix -- -e cobra-beszel-agent.age -i /secure/path/admin-identity
cd ..
```

After the editor exits:

```console
git status --short
git diff --stat
make nix-check
```

Review that only the intended encrypted file and any deliberate configuration
changes are present. Do not decrypt a secret merely to include its value in a
review, terminal transcript, or commit message.

## Deploy a rotated application secret

Use this order so the old credential remains available until the new one is
confirmed:

1. Create or rotate the credential in the upstream application.
2. Update the matching encrypted `.age` file.
3. Run `make nix-check`, commit, push, and let CI build the host.
4. Run `make remote-test` or `make remote-switch` against the pushed branch.
5. Restart the consuming service if it did not restart during activation.
6. Verify the service connection and logs.
7. Revoke the old credential only after the new one works.

For the Beszel agent specifically:

```console
make remote-switch REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
ssh cobra sudo systemctl restart podman-beszel-agent-intel.service
ssh cobra sudo systemctl status podman-beszel-agent-intel.service --no-pager
ssh cobra sudo journalctl -u podman-beszel-agent-intel.service -n 100 --no-pager
```

The encrypted file can be committed. The plaintext token, administrator
private key, Cobra private host key, and `/run/agenix` contents cannot.

## Rekey after a host-key change

Use this procedure when a reinstall or intentional SSH host-key rotation gives
Cobra a new `/etc/ssh/ssh_host_ed25519_key.pub`.

1. On Cobra, display and securely copy the new **public** key:

   ```console
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. On the administrator workstation, replace only the `cobra` public key in
   `secrets/secrets.nix`. Keep the verified `admin` recovery recipient.

3. From the secrets directory, re-encrypt every managed payload for the new
   recipient set:

   ```console
   cd secrets
   nix run github:ryantm/agenix -- -r -i /secure/path/admin-identity
   cd ..
   ```

4. Confirm all declared files were rekeyed:

   ```console
   git status --short
   git diff --stat
   make nix-check
   ```

5. Commit and push `secrets/secrets.nix` and every changed `.age` file. The
   GitHub-based deployment cannot see local-only ciphertext.

6. Build or test the pushed branch on Cobra. Activation should populate every
   declared secret without a decryption error.

Do not remove the old Cobra recipient until the new host public key is verified
and the rekey succeeds. If the administrator private key cannot decrypt the
old ciphertext and the old Cobra private key is gone, the encrypted payloads
cannot be recovered; issue new upstream credentials instead.

## Add a new secret

1. Add the new filename and intended public recipients to `secrets/secrets.nix`.
2. Create it with `make agenix-edit AGE_FILE=<name>.age`.
3. Declare `age.secrets.<name>` in the host or service module.
4. Pass `config.age.secrets.<name>.path` to the consumer as a runtime file.
5. Validate, commit the encrypted payload and declarations, deploy, and verify.

Never use `builtins.readFile` to read decrypted secret material into a Nix
expression: evaluated values can enter the world-readable Nix store.
