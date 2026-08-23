let
  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFj6f+QSQTQzgUEXdI+ZaP4WEuyRL5p6X91NxlZOIG0Q";
  cobra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUS8G9GBmVNBtWg34UFVYn06WN9mLyKsIIeSBOCL2m3";
  edge-1217 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRIHsOoPZ8h3T3oaX8YXefEK7CaLXJMgew/JJ1uoWRn";

in {
  # ------------------------------------------------------------
  # HOST SPECIFIC
  # ------------------------------------------------------------
  "cobra-beszel-agent.age".publicKeys = [
    admin
    cobra
  ];

  "cobra-homarr-encryption-key.age".publicKeys = [
    admin
    cobra
  ];

  "cobra-container-backup-restic-password.age".publicKeys = [
    admin
    cobra
  ];

  # ------------------------------------------------------------
  # GENERAL
  # ------------------------------------------------------------
  "beszel-agent.age".publicKeys = [
    admin
    cobra
    edge-1217
  ];

  "docktail-oauth.age".publicKeys = [
    admin
    cobra
  ];

  "pocket-id-encryption-key.age".publicKeys = [
    admin
    cobra
  ];

  "tailscale-oauth.age".publicKeys = [
    admin
    cobra
    edge-1217
  ];
}
