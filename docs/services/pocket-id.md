# Configure and operate Pocket ID

[`service_pocket-id.nix`](../../services/service_pocket-id.nix) runs Pocket ID
as the `id` Podman container on the `proxy` network. Docktail exposes it at:

```text
https://id.unicorn-stargazer.ts.net
```

The URL is derived from `fleet.tailscale.magicDnsSuffix` in
[`hosts/cobra/configuration.nix`](../../hosts/cobra/configuration.nix). Pocket
ID stores persistent application data in the rootful Podman named volume
`pocket-id.data`.

## Encryption key

Pocket ID reads its encryption key from `/run/secrets/pocket-id-encryption-key`
inside the container. Agenix decrypts
[`secrets/pocket-id-encryption-key.age`](../../secrets/pocket-id-encryption-key.age)
on the host, and the service mounts that runtime file read-only into the
container.

The encrypted payload contains only the raw encryption key, without a trailing
newline. Generate it and send it directly to Agenix for a new installation:

```console
openssl rand -base64 32 | tr -d '\n' | make agenix-edit AGE_FILE=pocket-id-encryption-key.age
```

Follow the repository's [Agenix runbook](../secrets.md) when editing or
deploying the secret. Never put the plaintext key in Nix configuration, Git,
shell history, or a command-line argument.

## Initial deployment

After validating and deploying the configuration, verify the runtime secret,
container, and proxy without displaying the key:

```console
sudo test -s /run/agenix/pocket-id-encryption-key
sudo systemctl status podman-id.service podman-docktail.service --no-pager
sudo journalctl -u podman-id.service -n 100 --no-pager
sudo podman inspect id --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

The mount list should include the named data volume at `/app/data` and the
Agenix runtime secret at `/run/secrets/pocket-id-encryption-key`.

From a device connected to the tailnet, open the Pocket ID URL and complete its
initial application setup.

## Backups and key changes

Back up `pocket-id.data` through the fleet's application-data backup process.
The named volume is not part of this Git repository.

Do not replace the encryption key after Pocket ID contains data unless you are
following Pocket ID's supported encryption-key rotation procedure. Losing or
incorrectly replacing this key can make encrypted application data unusable.

Before a reinstall, ensure the data volume backup and the Agenix recovery
identity have both been tested. Restoring only one of them is insufficient.
