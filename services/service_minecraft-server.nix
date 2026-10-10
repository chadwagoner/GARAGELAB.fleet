{ lib, ... }:

{
  virtualisation.oci-containers.containers.minecraft-server = {
    image = "docker.io/itzg/minecraft-bedrock-server:2026.9.2@sha256:244e72a36a3e3d69c588cbeefe6d8f6f97c48869b801718a4023570654e3b3d9";
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
