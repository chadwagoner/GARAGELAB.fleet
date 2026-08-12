{ config, pkgs, ... }:

{
  system.autoUpgrade = {
    enable = true;

    flake =
      "github:chadwagoner/GARAGELAB.fleet#${config.networking.hostName}";

    dates = "Sun 04:00";
    randomizedDelaySec = "30min";

    allowReboot = false;
  };
}
