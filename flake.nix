{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Due to https://github.com/hercules-ci/flake-parts/pull/251 this needs to be here, and not in invidual flakes.
    quadlet-nix = {
      url = "github:SEIAROTg/quadlet-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    appflowy = {
      url = "./appflowy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    testServer = {
      url = "./testServer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caddy = {
      url = "./caddy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mmx = {
      url = "./mmx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chia = {
      url = "./chia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nicehash = {
      url = "./nicehash";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      appflowy,
      quadlet-nix,
      testServer,
      caddy,
      nicehash,
      mmx,
      chia,
      ...
    }@attrs:
    {

      nixosModules = {
        quadlet-collection = {
          imports = [
            appflowy.nixosModules.quadlet
            quadlet-nix.nixosModules.quadlet
            caddy.nixosModules.quadlet
            chia.nixosModules.quadlet
            # nicehash does not have folders that need to be created
            mmx.nixosModules.quadlet
            # testServer does not have any folders that need to be created
          ];
        };
      };

      homeManagerModules = {
        quadlet-collection =
          { config, pkgs, ... }:

          {

            imports = [
              appflowy.homeManagerModules.quadlet
              quadlet-nix.homeManagerModules.quadlet
              testServer.homeManagerModules.quadlet
              caddy.homeManagerModules.quadlet
              mmx.homeManagerModules.quadlet
              chia.homeManagerModules.quadlet
              nicehash.homeManagerModules.quadlet
            ];

          };
      };
    };
}
