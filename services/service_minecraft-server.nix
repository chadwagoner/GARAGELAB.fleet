{ lib, ... }:

{
  virtualisation.oci-containers.containers.minecraft-server = {
    image = "docker.io/itzg/minecraft-bedrock-server:2026.9.1@sha256:83bdd41fd0574eb71368a58b2c0b9ecfe305559056d65e83878c20aae86a0015";
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
