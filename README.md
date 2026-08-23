# GARAGELAB.fleet

Step-by-step host bootstrap, secret rotation, and service runbooks are in
[`docs/`](docs/README.md). Start with the
[Cobra bootstrap guide](docs/cobra-bootstrap.md).

## Commands

Run `make` to list the available repository tasks. Common workflows include:

```console
make git-cleanup-preview
make git-cleanup
make git-pr-create
make nix-check
make nix-eval
```

The Nix validation targets work on an Apple Silicon Mac without building the
Linux system closure. The `cobra` configuration targets `x86_64-linux`, so full
builds and activation run over SSH on the NixOS host:

```console
make remote-build
make remote-dry-activate
make remote-test
make remote-switch
```

The defaults are configurable. For example, use a different SSH destination
while keeping the `cobra` flake output:

```console
make remote-build REMOTE=admin@192.0.2.10 HOST=cobra
```

Remote targets use the repository's default GitHub branch unless
`REMOTE_FLAKE` is overridden. To test a pushed feature branch, use for example
`REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch`.

`remote-test` activates the result until reboot; `remote-switch` makes it the
boot default. Use `make remote-status` to show failed units and recent boot
errors after activation. Use `make remote-auto-upgrade-status` to show the
automatic-upgrade timer, last service result, and logs from the previous eight
days. Override the log window with, for example,
`AUTO_UPGRADE_SINCE="30 days ago"`.

## NixOS troubleshooting

Useful local macOS checks:

```console
make nix-info              # Confirm aarch64-darwin and the active Nix version
make nix-config-check      # Check Nix paths, profiles, and daemon connectivity
make nix-parse             # Catch syntax errors without evaluating imports
make nix-show              # Inspect the flake outputs
make nix-eval              # Evaluate cobra's system derivation
make nix-check             # Parse and run flake checks without a Linux build
```

Useful commands on the NixOS host:

```console
sudo nixos-rebuild list-generations
systemctl --failed
journalctl -b -p err..alert
journalctl -u podman-<service>.service -n 100 --no-pager
sudo nixos-rebuild switch --rollback
```

## Containers

Podman is the OCI runtime. Add each declarative container as a NixOS module in
[`services/`](services/), following the
[container service standards](docs/services/README.md). Renovate checks those
image references for weekly tag and digest updates.
