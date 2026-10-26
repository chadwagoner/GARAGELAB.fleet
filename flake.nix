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
      checks.x86_64-linux.container-backup = import ./tests/container-backup.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };

      nixosConfigurations.cobra = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./profiles/base.nix
          # Keep host-only modules at the same import depth as the base modules.
          { imports = [ ./modules/nfs.nix ./modules/container-backup.nix ]; }
          ./profiles/container-host.nix
          ./hosts/cobra/services.nix
          ./hosts/cobra/configuration.nix
        ];
      };

      nixosConfigurations."edge-1217" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./profiles/base.nix
          ./profiles/container-host.nix
          ./hosts/edge-1217/services.nix
          ./hosts/edge-1217/configuration.nix
        ];
      };

      nixosConfigurations."edge-6201" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./profiles/base.nix
          ./profiles/container-host.nix
          ./hosts/edge-6201/services.nix
          ./hosts/edge-6201/configuration.nix
        ];
      };
    };
}
