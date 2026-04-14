{
  description = "maelstrom home server";

  inputs = {
    nixpkgs.url  = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url   = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, agenix, ... }: {
    nixosConfigurations.maelstrom = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        agenix.nixosModules.default
        ./configuration.nix
        ./hardware-configuration.nix
      ];
    };
  };
}
