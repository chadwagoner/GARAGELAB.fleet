{
  description = "GARAGELAB.fleet configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, agenix, ... }:
    {
      nixosConfigurations.cobra = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          agenix.nixosModules.default
          ./modules/common.nix
          ./modules/nfs.nix
          ./modules/podman.nix
          ./modules/ssh.nix
          ./modules/tailscale.nix
          ./modules/users.nix
          ./modules/auto-upgrade.nix
          ./services/group_cobra.nix
          ./modules/container-backup.nix
          ./hosts/cobra/configuration.nix
        ];
      };

      nixosConfigurations."edge-1217" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          agenix.nixosModules.default
          ./modules/common.nix
          ./modules/podman.nix
          ./modules/ssh.nix
          ./modules/tailscale.nix
          ./modules/users.nix
          ./modules/auto-upgrade.nix
          ./services/group_edge-1217.nix
          ./hosts/edge-1217/configuration.nix
        ];
      };

      nixosConfigurations."edge-6201" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          agenix.nixosModules.default
          ./modules/common.nix
          ./modules/podman.nix
          ./modules/ssh.nix
          ./modules/tailscale.nix
          ./modules/users.nix
          ./modules/auto-upgrade.nix
          ./services/group_edge-6201.nix
          ./hosts/edge-6201/configuration.nix
        ];
      };
    };
}
