# nix-podman-sshServerJohannes-quadlet
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs =
    { nixpkgs, ... }@attrs:
    {
      homeManagerModules.quadlet =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.nix-podman-sshServerJohannes-quadlet;
        in
        {

          options.services.nix-podman-sshServerJohannes-quadlet = {
            enable = lib.mkEnableOption "nix-podman-sshServerJohannes-quadlet";
          };

          config = lib.mkIf cfg.enable {
            systemd.user.startServices = "sd-switch";

            virtualisation.quadlet.containers = {
              testServer = {
                autoStart = true;
                serviceConfig = {
                  RestartSec = "10";
                  Restart = "always";
                };
                containerConfig = {
                  environments = {
                      PUID = "1000";
                      PGID = "1000";
                      PUBLIC_KEY_DIR = "/pubkeys";
                      SUDO_ACCESS = "true";
                      PASSWORD_ACCESS = "false";
                      USER_NAME = "johannes";
                  };
                  image = "lscr.io/linuxserver/openssh-server:latest";
                  publishPorts = [ "17693:2222" ];

                  volumes = [
                    "/media/noob/config/:/config"
                    "/media/noob/system/:/system"
                    "/media/noob/data/:/data"
                    "/media/noob/pubkeys/:/pubkeys"
                  ];
                };
              };
            };
          };
        };
    };
}
