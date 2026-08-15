# Bootstrap Cobra after installing NixOS

This guide starts after a basic NixOS installation boots successfully on
Cobra. It connects that installation to `GARAGELAB.fleet`, validates the
machine-specific configuration, and safely performs the first activation.

The current flake output is `cobra` on `x86_64-linux`. It declares a static LAN
address, SSH access for the `nix` user, Tailscale, NFS mounts, Podman services,
and Agenix secrets. Do not activate it unchanged on a different machine.

## 0. Before reinstalling, if the old system is still available

Preserve these outside the repository on encrypted, access-controlled storage:

- `/etc/ssh/ssh_host_ed25519_key`
- `/etc/ssh/ssh_host_ed25519_key.pub`
- application data and Podman volumes that must survive the reinstall

The SSH private host key is both Cobra's SSH identity and its default Agenix
decryption identity. Restoring it keeps the existing encrypted secrets usable
and avoids a new SSH host-key warning. Never copy this private key into Git.

If the old private key is unavailable, continue with the new key created by the
installer and follow [Rekey after a host-key change](secrets.md#rekey-after-a-host-key-change)
before the first fleet activation.

## 1. Verify the base installation

Log in at the local console and confirm the machine, network, and generated SSH
host key:

```console
uname -m
ip -brief link
ip route
findmnt -no SOURCE,FSTYPE /
findmnt -no SOURCE,FSTYPE /boot
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

Expected architecture is `x86_64`. Compare the remaining output with the
checked-in configuration:

- [`hosts/cobra/hardware-configuration.nix`](../hosts/cobra/hardware-configuration.nix)
  contains the root and boot filesystem UUIDs.
- [`hosts/cobra/configuration.nix`](../hosts/cobra/configuration.nix) uses
  interface `enp86s0`, address `192.168.128.3/24`, gateway
  `192.168.128.1`, and DNS server `192.168.128.1`.

A reinstall commonly changes filesystem UUIDs. A hardware or cabling change
can also change the interface name. Correct those values before activation or
the system may fail to boot or lose its network connection.

Generate a fresh hardware file for comparison without overwriting the tracked
file:

```console
generated_hardware="$(mktemp)"
sudo nixos-generate-config --show-hardware-config > "$generated_hardware"
diff -u hosts/cobra/hardware-configuration.nix "$generated_hardware"
```

Review intentional differences, then update the tracked hardware file as
needed. Do not blindly copy configuration from a different machine.

## 2. Restore or rekey Cobra's SSH host identity

Choose exactly one path.

### Restore the preserved identity

From local console access, install the backed-up files with their original
ownership and permissions:

```console
sudo install -o root -g root -m 0600 /secure/path/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
sudo install -o root -g root -m 0644 /secure/path/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
sudo systemctl restart sshd.service
```

Confirm that the public key equals the `cobra` recipient in
[`secrets/secrets.nix`](../secrets/secrets.nix):

```console
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

### Keep the newly generated identity

Copy only `/etc/ssh/ssh_host_ed25519_key.pub` to the trusted administrator
workstation. Replace the `cobra` public recipient and rekey every encrypted
secret by following the linked [secret runbook](secrets.md#rekey-after-a-host-key-change).
Commit and push those encrypted changes before using a GitHub flake URL.

## 3. Clone the repository

The repository can be cloned over HTTPS; Cobra does not need a GitHub private
key to evaluate a public GitHub flake:

```console
git clone https://github.com/chadwagoner/GARAGELAB.fleet.git
cd GARAGELAB.fleet
git status --short
```

For a feature branch, check it out before building. If the hardware file was
updated locally, keep that reviewed change in this checkout for the first
host-local build, then commit it through the normal pull-request workflow.

## 4. Review access before activation

The fleet configuration creates the `nix` user, grants passwordless `wheel`
access, and accepts the public SSH key in [`modules/users.nix`](../modules/users.nix).
SSH password and root login are disabled by [`modules/ssh.nix`](../modules/ssh.nix).

Before proceeding, verify that the private administrator key matching the
declared public key is available on the computer from which you will connect.
Keep the local console session open through the first activation.

Also review the host-specific settings that can affect availability:

```console
git diff -- hosts/cobra/hardware-configuration.nix hosts/cobra/configuration.nix modules/users.nix
```

## 5. Validate and build

Run the repository checks, then build without activating:

```console
make nix-parse
make nix-check
sudo nixos-rebuild build --flake .#cobra
```

The build must complete before continuing. An Agenix decryption error at this
stage or during activation means the current host private key is not a
recipient for one or more secrets; fix the recipient policy and rekey rather
than copying plaintext onto the host.

## 6. Test the configuration

Temporarily activate the result:

```console
sudo nixos-rebuild dry-activate --flake .#cobra
sudo nixos-rebuild test --flake .#cobra
```

From a second computer, verify the declared account while the console remains
open:

```console
ssh nix@192.168.128.3
sudo true
```

On Cobra, check the base system and secrets activation:

```console
systemctl --failed
systemctl status sshd.service tailscaled.service --no-pager
sudo test -s /run/agenix/tailscale-oauth
sudo test -s /run/agenix/cobra-beszel-agent
```

`test -s` verifies that a runtime file exists without printing its secret.

## 7. Make the configuration persistent

After SSH, networking, storage, and required services work under the test
generation:

```console
sudo nixos-rebuild switch --flake .#cobra
sudo nixos-rebuild list-generations
systemctl --failed
```

If activation causes a problem, return to the console and use:

```console
sudo nixos-rebuild switch --rollback
```

## 8. Use the normal remote workflow

Once Cobra is reachable as the `nix` user, routine operations can run from the
administrator workstation:

```console
make remote-build
make remote-dry-activate
make remote-test
make remote-switch
make remote-status
```

These targets default to the pushed GitHub repository. Local, uncommitted
changes are not included. To test a pushed branch:

```console
make remote-test REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
```

After the base host is stable, continue with the
[Beszel setup and operations guide](services/beszel.md).
