# Container services

Declare each Podman workload in its own NixOS module in this directory, then
add that module to the appropriate `group_<host>.nix`. Keeping the import
explicit makes the deployment change visible in review.

Use the NixOS `virtualisation.oci-containers.containers` module rather than a
separate Compose file. NixOS will create a `podman-<name>.service` systemd unit,
send logs to journald, and start the container at boot by default.

## Service skeleton

```nix
{ ... }:

{
  virtualisation.oci-containers.containers.example = {
    image = "ghcr.io/example/example:1.2.3";
    ports = [ "127.0.0.1:8080:8080" ];
    volumes = [ "/var/lib/example:/data" ];
  };
}
```

Use a versioned tag instead of `latest`. Renovate matches `image = "...";`
declarations in `services/*.nix`, pins the selected image to an immutable
digest, and opens weekly PRs for tag or digest changes. Merging the PR updates
the declarative image used at the next NixOS switch.

## Operational guidance

- Bind published ports to `127.0.0.1` unless the service must be reachable
  directly from the network. Podman-published ports bypass the NixOS firewall.
- Store persistent state in an explicit host directory or named volume and
  include its backup policy with the service.
- Put secrets in a managed runtime file and reference it with
  `environmentFiles`; do not commit secret values in `environment`.
- Prefer a dedicated rootless Podman user when the workload supports it.
  Rootful containers should be reserved for services that need host devices,
  privileged ports, or similar access.
- Review image release notes and let the NixOS CI build pass before merging a
  Renovate PR. Container image updates are intentionally not automerged.
