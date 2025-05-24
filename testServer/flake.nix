{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, home-manager, ... }@attrs:
    {
      homeManagerModules.quadlet =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.nix-podman-testServer-quadlet;
        in
        {

          options.services.nix-podman-testServer-quadlet = {
            enable = lib.mkEnableOption "nix-podman-testServer-quadlet";
          };

          config = lib.mkIf cfg.enable {
            systemd.user.startServices = "sd-switch";

            services.podman.containers.testServer = {
              autoStart = true;
              extraConfig = {
                Service = {
                  Restart = "always";
                  RestartSec = "10";
                };
                Container = {
                  Image = "quay.io/libpod/banner:latest";
                  PublishPort = [ "8002:80" ];
                };
              };
            };
          };
        };
    };
}
