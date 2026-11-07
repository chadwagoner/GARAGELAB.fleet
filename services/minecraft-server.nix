{ lib, ... }:

{
  virtualisation.oci-containers.containers.minecraft-server = {
    image = "docker.io/itzg/minecraft-bedrock-server:2026.10.3@sha256:ad8243d09604051085702536d1e9fef4b0a97fb308f2f2fa73c3fb56b5f4c580";
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
