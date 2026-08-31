# Home Assistant Zigbee2MQTT

Home Assistant Zigbee2MQTT is an optional Cobra service. Home Assistant
Mosquitto is enabled separately and provides the local MQTT broker that Home
Assistant Zigbee2MQTT requires.

## Find the coordinator

Connect the coordinator to Cobra and run:

```sh
ls -l /dev/serial/by-id
```

Use the complete `/dev/serial/by-id/...` target as `serialDevice`. The module
maps that stable host path to `/dev/ttyACM0` inside the container. If adapter
autodetection does not work, set `adapter` to the adapter name supported by
the coordinator (for example, the value documented for `zstack` or `ember`).

## Enable it

Create an agenix-managed runtime environment file containing the token line
(do not put the token in Nix or in `environment`):

```text
ZIGBEE2MQTT_CONFIG_FRONTEND_AUTH_TOKEN=replace-with-a-long-random-token
```

Register and decrypt that secret with agenix, then point `frontend.authTokenFile`
at its runtime path. A complete configuration looks like this:

```nix
fleet.service.home-assistant-zigbee2mqtt = {
  enable = true;
  serialDevice = "/dev/serial/by-id/your-coordinator";
  adapter = null;
  frontend = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    authTokenFile = config.age.secrets.cobra-home-assistant-zigbee2mqtt-frontend-auth-token.path;
  };
};
```

The module asserts that Home Assistant Mosquitto is enabled, a coordinator
path is set, and an auth-token runtime file is supplied whenever the frontend
is enabled.

## Volume migration

This is a declarative rename only; no automatic data migration is performed.
If existing named volumes should be retained, migrate them separately:

- `mosquitto.data` → `home-assistant-mosquitto.data`
- `zigbee2mqtt.data` → `home-assistant-zigbee2mqtt.data`

## MQTT and network access

Zigbee2MQTT connects to the broker at `mqtt://127.0.0.1:1883` and enables Home
Assistant MQTT discovery. Configure Home Assistant's MQTT integration to use
host `127.0.0.1` and port `1883` as well.

Both containers use host networking. Home Assistant Mosquitto listens only on loopback, so
port 1883 is not exposed to the LAN. The Zigbee2MQTT frontend defaults to
loopback on TCP port 8080. Setting `frontend.host` to `0.0.0.0` makes it
reachable on the LAN and the module opens its configured TCP port in the NixOS
firewall; keep the frontend auth token enabled in that case.
