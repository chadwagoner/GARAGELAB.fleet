{ config, pkgs, ... }:

{
  users.users.nix = {
    uid = 1000;
    group = "users";
    isNormalUser = true;

    extraGroups = [
      "wheel"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFj6f+QSQTQzgUEXdI+ZaP4WEuyRL5p6X91NxlZOIG0Q"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
