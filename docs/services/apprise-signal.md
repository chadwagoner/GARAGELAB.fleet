# Apprise API and Signal CLI REST API

[`service_apprise.nix`](../../services/service_apprise.nix) and
[`service_signal-api.nix`](../../services/service_signal-api.nix) run the
Apprise API and Signal CLI REST API on Cobra's `proxy` network. Docktail
provides HTTPS on the tailnet at:

```text
https://apprise.unicorn-stargazer.ts.net
https://signal-api.unicorn-stargazer.ts.net
```

The hostnames use Cobra's Tailscale MagicDNS suffix. Neither container
publishes a host port. Keep both services restricted to the tailnet: their APIs
can trigger notifications or operate a linked Signal account and should not be
exposed to the public internet.

## Apprise

This runs the Apprise API service (not just the Apprise Python library), with
`APPRISE_STATEFUL_MODE=simple`. Its named volume `apprise.config` persists
service configuration at `/config`; the optional `/attach` storage is not
mounted because no attachment persistence is configured. Verify the API from
a tailnet-connected device at:

```text
https://apprise.unicorn-stargazer.ts.net/status
```

Review the Apprise API documentation before adding integrations. Treat
configuration and any notification URLs or credentials stored there as
sensitive; include `apprise.config` in protected backups and test restoration.

## Signal CLI REST API

The API uses upstream's minimal `MODE=native` configuration. From a
tailnet-connected device, open
`https://signal-api.unicorn-stargazer.ts.net/v1/qrcodelink?device_name=signal-api`
and scan the QR code with Signal's linked-devices flow to link the account.
The generated QR code grants account access; do not share it or leave it
accessible to untrusted users. Check the API's `/v1/about` endpoint and consult
the upstream signal-cli-rest-api API documentation for available operations.

Signal account and registration state is persisted in the named volume
`signal-api.data`, mounted at `/home/.local/share/signal-cli`. This data is
sensitive: protect backups accordingly, and test that a restore retains the
linked-device state. Re-link through the QR flow if required after recovery.
