{
  description = "GARAGELAB.fleet configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }:
    {
      nixosConfigurations.cobra = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./modules/common.nix
          ./modules/ssh.nix
          ./modules/users.nix
          ./modules/auto-upgrade.nix
          ./hosts/cobra/configuration.nix
        ];
      };
    };
}
