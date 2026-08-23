# Manage and rotate Agenix secrets

This repository stores encrypted Agenix payloads in [`secrets/`](../secrets/).
The recipient policy in [`secrets/secrets.nix`](../secrets/secrets.nix) grants
decryption to the public identities assigned to each file:

- `admin`: the administrator/recovery SSH key used to edit or rekey secrets
- host recipients such as `cobra` and `edge-1217`: the corresponding host's
  `/etc/ssh/ssh_host_ed25519_key.pub`

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
private key, host private keys, and `/run/agenix` contents cannot.

## Rekey after a recipient change

Use this procedure after adding a host recipient, removing a recipient, or when
a reinstall or intentional SSH host-key rotation changes a host's
`/etc/ssh/ssh_host_ed25519_key.pub`.

1. On the affected host, display and securely copy the new **public** key:

   ```console
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. On the administrator workstation, update the intended `publicKeys` entries
   in `secrets/secrets.nix`. Keep the verified `admin` recovery recipient.

3. From the repository root, re-encrypt every managed payload for the current
   recipient policy. If Agenix can discover the administrator identity through
   the SSH agent or standard key paths, run:

   ```console
   make agenix-rekey
   ```

   Otherwise, provide the private identity explicitly:

   ```console
   make agenix-rekey AGENIX_IDENTITY=/secure/path/admin-identity
   ```

   To re-encrypt only one existing secret, pass its path relative to the
   `secrets/` directory. This uses Agenix's edit operation with a no-op editor,
   preserving the plaintext while applying the file's current recipients:

   ```console
   make agenix-rekey AGE_FILE=tailscale-oauth.age
   ```

   The file and identity options can be combined:

   ```console
   make agenix-rekey \
     AGE_FILE=tailscale-oauth.age \
     AGENIX_IDENTITY=/secure/path/admin-identity
   ```

4. Confirm the intended encrypted files were rekeyed:

   ```console
   git status --short
   git diff --stat
   make nix-check
   ```

5. Commit and push `secrets/secrets.nix` and every changed `.age` file. The
   GitHub-based deployment cannot see local-only ciphertext.

6. Build or test the pushed branch on each affected host. Activation should
   populate every declared secret without a decryption error.

Do not remove an old host recipient until the new host public key is verified
and the rekey succeeds. If the administrator private key cannot decrypt the
old ciphertext and the old host private key is gone, the encrypted payloads
cannot be recovered; issue new upstream credentials instead.

## Add a new secret

1. Add the new filename and intended public recipients to `secrets/secrets.nix`.
2. Create it with `make agenix-edit AGE_FILE=<name>.age`.
3. Declare `age.secrets.<name>` in the host or service module.
4. Pass `config.age.secrets.<name>.path` to the consumer as a runtime file.
5. Validate, commit the encrypted payload and declarations, deploy, and verify.

Never use `builtins.readFile` to read decrypted secret material into a Nix
expression: evaluated values can enter the world-readable Nix store.
