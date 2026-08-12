# GARAGELAB.fleet

## CONTAINERS

Podman is the OCI runtime. Add each declarative container as a NixOS module in
[`services/`](services/README.md); Renovate checks those image references for
weekly tag and digest updates.

## BUILD
sudo nixos-rebuild build --flake github:chadwagoner/GARAGELAB.fleet#cobra --refresh

## TEST
sudo nixos-rebuild test --flake github:chadwagoner/GARAGELAB.fleet#cobra --refresh

## SWITCH
sudo nixos-rebuild switch --flake github:chadwagoner/GARAGELAB.fleet#cobra --refresh
