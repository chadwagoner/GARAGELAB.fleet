{ lib, ... }:

{
  virtualisation.oci-containers.containers.minecraft-server = {
    image = "docker.io/itzg/minecraft-bedrock-server:2026.11.1@sha256:463ea4ac99a3e5b67de0fc590a61cca7ea758520f67d9e4a4512fc3afcc97044";
    environment = {
      ALLOW_CHEATS = "true";
      ALLOW_LIST = "false";
      DEFAULT_PLAYER_PERMISSION_LEVEL = "operator";
      DIFFICULTY = "peaceful";
      EULA = "true";
      GAMEMODE = "creative";
      # ONLINE_MODE = "false";
      SERVER_PORT = "19132";
    };
    extraOptions = [
      "--memory=8g"
      "--memory-reservation=2g"
    ];
    ports = [
      "19132:19132/tcp"
      "19132:19132/udp"
    ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "minecraft-server.config:/config"
      "minecraft-server.data:/data"
    ];
  };

  systemd.services.podman-minecraft-server.serviceConfig.Restart =
    lib.mkForce "always";
}
