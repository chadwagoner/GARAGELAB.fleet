# GARAGELAB.fleet documentation

These runbooks describe how to bootstrap and operate the NixOS hosts managed by
this repository. They are written for the current `cobra` host and should be
updated alongside any change to its hardware, network, secrets, or services.

## Start here

1. [Bootstrap Cobra after installing NixOS](cobra-bootstrap.md)
2. [Manage and rotate Agenix secrets](secrets.md)
3. [Container service standards and runbooks](services/README.md)

Service-specific guides:

- [Beszel](services/beszel.md)
- [Pocket ID](services/pocket-id.md)

The root [`README.md`](../README.md) remains the command reference. The guides
in this directory explain when to use those commands and how to verify the
result.

## Safety boundaries

- Only encrypted `*.age` files and public recipient keys belong in Git.
- Never commit SSH private keys, decrypted secrets, generated environment
  files, tokens, or application data.
- Keep a local console open during a first network or SSH activation.
- Use `nixos-rebuild test` before `switch`; `test` does not change the boot
  default and a reboot returns to the previous generation.
