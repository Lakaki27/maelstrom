{
  description = "maelstrom home server";

  inputs = {
    nixpkgs.url  = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url   = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, agenix, deploy-rs, ... }: {
    nixosConfigurations.maelstrom = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        agenix.nixosModules.default
        ./configuration.nix
        ./hardware-configuration.nix
      ];
    };

    deploy.nodes.maelstrom = {
      hostname = "maelstrom.home";
      sshUser = "maelstrom";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.maelstrom;
      };
    };

    checks = builtins.mapAttrs
      (system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;
  };
}
