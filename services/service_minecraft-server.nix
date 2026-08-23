{ lib, ... }:

{
  virtualisation.oci-containers.containers.minecraft-server = {
    image = "docker.io/itzg/minecraft-bedrock-server:2026.8.2@sha256:6bb1cb8ee0c1fdf96dbd9dfe77bed4e20c8e3946112bed4f9be609e8f14efe9a";
    environment = {
      ALLOW_CHEATS = "true";
      DEFAULT_PLAYER_PERMISSION_LEVEL = "operator";
      DIFFICULTY = "peaceful";
      EULA = "true";
      GAMEMODE = "creative";
      ONLINE_MODE = "false";
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
