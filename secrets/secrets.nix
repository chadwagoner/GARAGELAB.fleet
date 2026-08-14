let
  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFj6f+QSQTQzgUEXdI+ZaP4WEuyRL5p6X91NxlZOIG0Q";
  cobra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUS8G9GBmVNBtWg34UFVYn06WN9mLyKsIIeSBOCL2m3";

in {
  "docktail-oauth.age".publicKeys = [
    admin
    cobra
  ];

  "tailscale-oauth.age".publicKeys = [
    admin
    cobra
  ];
}
