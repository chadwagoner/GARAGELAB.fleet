# Configure and operate Beszel

Cobra runs both parts of Beszel:

- [`service_beszel.nix`](../../services/service_beszel.nix) runs the hub on the
  `proxy` Podman network and exposes it through Docktail at
  `https://beszel.unicorn-stargazer.ts.net`.
- [`service_beszel-agent-intel.nix`](../../services/service_beszel-agent-intel.nix)
  runs the Intel GPU agent with host networking and Podman socket access.
- [`hosts/cobra/configuration.nix`](../../hosts/cobra/configuration.nix) supplies
  the hub public key and the Agenix-managed token file.

The agent sets `DISABLE_SSH=true`, so it uses an outbound WebSocket connection
to the hub. The hub URL, hub public key, and token must agree with the current
hub. Beszel documents these as the required agent values for this connection
mode in its [agent installation guide](https://beszel.dev/guide/agent-installation)
and supports `TOKEN_FILE` for protected file input in its
[environment-variable reference](https://beszel.dev/guide/environment-variables).

## 1. Decide whether this is a restore or a new hub

The hub state lives in the rootful Podman named volume `beszel.data`. The agent
state lives in `beszel-agent-intel.data`.

- If restoring a known-good `beszel.data` backup, retain the matching hub
  public key and agent token unless Beszel requests new registration.
- If the volume was lost or this is a new installation, the new hub has a new
  identity. Complete the registration steps below and replace the old values.

Treat these volumes as application data. They are not stored in this Git
repository and require a separate tested backup and restore process.

## 2. Start the hub

Deploy the fleet configuration, then verify the hub and Docktail proxy:

```console
sudo systemctl status podman-beszel.service podman-docktail.service --no-pager
sudo journalctl -u podman-beszel.service -n 100 --no-pager
sudo podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}'
```

From a device connected to the tailnet, open:

```text
https://beszel.unicorn-stargazer.ts.net
```

Complete Beszel's first-user setup if the hub data volume is new. If the URL is
unavailable, verify `tailscaled`, `podman-docktail`, and the `proxy` network
before changing Beszel credentials.

## 3. Register Cobra in the hub

In the Beszel web UI:

1. Choose **Add System** and use `cobra` as the system name.
2. Use the WebSocket/agent-initiated connection values supplied by the hub.
3. Record the generated `KEY` public key and `TOKEN` in a secure temporary
   location. Do not put the token in a shell command, issue, or plaintext file
   in the repository.
4. Replace `fleet.service.beszel-agent-intel.publicKey` in
   `hosts/cobra/configuration.nix` with the generated public key.
5. Store only the raw token in the encrypted payload:

   ```console
   EDITOR=vim make agenix-edit AGE_FILE=cobra-beszel-agent.age
   ```

6. Delete any temporary plaintext copy after confirming the encrypted edit.

The public key is not secret and belongs in Nix configuration. The token is a
credential and belongs only in `secrets/cobra-beszel-agent.age`.

## 4. Validate and deploy the agent

From the administrator workstation:

```console
make nix-check
git status --short
```

Commit and push the public-key configuration and encrypted token. After CI
passes, test the pushed branch:

```console
make remote-test REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
```

On Cobra, restart and inspect the agent:

```console
sudo test -s /run/agenix/cobra-beszel-agent
sudo systemctl restart podman-beszel-agent-intel.service
sudo systemctl status podman-beszel-agent-intel.service --no-pager
sudo journalctl -u podman-beszel-agent-intel.service -n 100 --no-pager
sudo podman inspect beszel-agent-intel --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

The mount list should include the Agenix source at the container destination
`/run/secrets/beszel-agent-token`, plus `/run/docker.sock` and the agent data
volume. Do not print the token from either the host or container.

Return to the hub and confirm Cobra is online and reporting host and container
metrics. If the temporary activation works, persist it:

```console
make remote-switch REMOTE_FLAKE=github:chadwagoner/GARAGELAB.fleet/my-branch
make remote-status
```

## 5. Verify Intel GPU metrics

The agent expects `/dev/dri/card0`, adds the `PERFMON` capability, and uses the
Intel-specific Beszel image. Verify the device on the host and in the
container:

```console
ls -l /dev/dri/card0
sudo podman exec beszel-agent-intel ls -l /dev/dri/card0
sudo journalctl -u podman-beszel-agent-intel.service -g 'gpu\|drm\|perf' --no-pager
```

If the Intel card is exposed under a different `/dev/dri/card*` path, set
`fleet.service.beszel-agent-intel.gpuDevice` in the host configuration rather
than editing the reusable service module.

## Rotate the Beszel agent token

1. In the Beszel hub, rotate or create the token used by Cobra.
2. Edit `cobra-beszel-agent.age` using the
   [secret rotation procedure](../secrets.md#edit-or-rotate-one-secret).
3. Validate, commit, push, and deploy the encrypted change.
4. Restart `podman-beszel-agent-intel.service`.
5. Confirm the agent reconnects and new metrics arrive.
6. Revoke the old token only after successful verification.

If the token changes but the old agent remains connected, confirm whether the
hub is displaying a current WebSocket connection rather than assuming the
rotation has taken effect.

## Change or replace the hub identity

A new hub data volume can change both the hub public key and registration
token. Update the public `publicKey` option and encrypted token together, then
deploy and restart the agent. A token-only update cannot correct a mismatched
hub public key.

## Common failures

### Agent cannot read its token

Check the host runtime file, service mount, and unit logs without displaying
the payload:

```console
sudo ls -l /run/agenix/cobra-beszel-agent
sudo podman inspect beszel-agent-intel --format '{{json .Mounts}}'
sudo journalctl -u podman-beszel-agent-intel.service -n 100 --no-pager
```

### Agent cannot connect to the hub

Verify the exact configured URL, DNS, HTTPS endpoint, and hub container:

```console
getent hosts beszel.unicorn-stargazer.ts.net
curl -I https://beszel.unicorn-stargazer.ts.net
sudo systemctl status podman-beszel.service podman-docktail.service --no-pager
```

Then compare the public key and token with the values generated by the current
hub. Do not work around the problem by enabling plaintext credentials.

### Container metrics are missing

The agent consumes Podman's Docker-compatible API through `/run/docker.sock`.
Verify both the socket unit and the mount:

```console
sudo systemctl status podman.socket --no-pager
sudo podman inspect beszel-agent-intel --format '{{json .Mounts}}'
```

Although mounted with `:ro`, the API socket provides effectively root-level
control of the host. Do not expose it to additional containers casually.
