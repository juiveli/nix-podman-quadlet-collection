# Nix-podman-appflowy-quadlet
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      nixpkgs,
      self,
      systems,
      treefmt-nix,
      ...
    }@attrs:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system:
          f {
            pkgs = import nixpkgs { system = system; };
          }
        );

      # Small tool to iterate over each system
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);

      packages = forAllSystems (
        { pkgs }:
        {
          appflowySource = pkgs.stdenv.mkDerivation {
            pname = "appflowy-source";
            version = "1.0";
            src = /home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud;
            unpackPhase = "true";
            installPhase = ''
              mkdir -p $out
              cp -r $src/* $out/
            '';
          };
        }
      );

    in
    {

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

      packages = packages;

      #

      nixosModules.quadlet =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let

          cfg = config.services.nix-podman-appflowy-quadlet;

        in
        {

          options.services.nix-podman-appflowy-quadlet = {
            folder-creations.enable = lib.mkEnableOption "nix-podman-appflowy-quadlet.folder-creations";

            username = lib.mkOption {
              type = lib.types.str;
              default = "joonas";
            };

            usergroup = lib.mkOption {
              type = lib.types.str;
              default = "users";
            };
          };

          config = lib.mkIf cfg.folder-creations.enable {

            systemd.tmpfiles.settings = {
              "containers_folder" = {
                "/var/lib/containers" = {

                  d = {
                    group = cfg.usergroup;
                    mode = "0755";
                    user = cfg.username;
                  };
                };
              };

              "appflowy_folders" = {
                "/var/lib/containers/appflowy" = {
                  d = {
                    group = cfg.usergroup;
                    mode = "0755";
                    user = cfg.username;
                  };
                };

                "/var/lib/containers/appflowy/minio_data" = {
                  d = {
                    group = cfg.usergroup;
                    mode = "0755";
                    user = cfg.username;
                  };
                };

                "/var/lib/containers/appflowy/postgres_data" = {
                  d = {
                    group = cfg.usergroup;
                    mode = "0755";
                    user = cfg.username;
                  };
                };
              };
            };
          };
        };

      homeManagerModules.quadlet =
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          cfg = config.services.nix-podman-appflowy-quadlet;

        in
        {

          options.services.nix-podman-appflowy-quadlet = {
            enable = lib.mkEnableOption "Enable nix-podman-appflowy-quadlet service.";
          };

          config = lib.mkIf cfg.enable {

            home.packages = [ self.packages.x86_64-linux.appflowySource ];
            systemd.user.startServices = "sd-switch";

            virtualisation.quadlet.pods = {
              appflowy_pod = { };
            };

            services.podman.builds = {
              appflowyinc_gotrue = {
                file = "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/docker/gotrue/Dockerfile";
                tags = [ "localhost/homemanager/appflowyinc_gotrue" ];

              };

              admin_frontend_build = {
                file = "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/admin_frontend/Dockerfile";
                tags = [ "admin_frontend_build" ];
                workingDirectory = "/home/joonas/tempo";
              };

              appflowy_worker_build = {
                file = "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/services/appflowy-worker/Dockerfile";
                tags = [ "appflowy_worker_build" ];
              };

              appflowy_cloud_build = {
                file = "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/Dockerfile";
                tags = [ "appflowy_cloud_build" ];
                # annotations = [ "FEATURES=" ];
              };
            };

            services.podman.containers.minio = {

              autoStart = true;
              extraConfig = {
                Service = {
                  Restart = "on-failure";
                  RestartSec = "10";
                };
              };

              image = "minio/minio";
              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              environment = {
                # MINIO_BROWSER_REDIRECT_URL=${APPFLOWY_BASE_URL}
                MINIO_BROWSER_REDIRECT_URL = "http://localhost";
                MINIO_ROOT_USER = "minioadmin";
                MINIO_ROOT_PASSWORD = "minioadmin";
              };

              exec = "server /data --console-address :9001";
              volumes = [
                "/var/lib/containers/appflowy/minio_data:/data"
              ];

            };

            services.podman.containers.postgres = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
              };
              image = "pgvector/pgvector:pg16";
              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              environment = {
                POSTGRES_USER = "postgres";
                POSTGRES_DB = "postgres";
                POSTGRES_PASSWORD = "password";
                POSTGRES_HOST = "postgres";
              };

              # Health Check Configuration
              # healthCmd = "CMD pg_isready -U ''${POSTGRES_USER}'' -d ''${POSTGRES_DB}''";
              # healthInterval = "5s";
              # healthTimeout = "5s";
              # healthRetries = 12;

              volumes = [
                "/var/lib/containers/appflowy/postgres_data:/var/lib/postgresql/data"
              ];
            };

            services.podman.containers.redis = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
              };
              image = "redis";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

            };

            services.podman.containers.gotrue = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
                Unit = {
                  After = [ "podman-postgres.service"];
                  Requires = [ "podman-postgres.service"];
                };
              };
              image = "appflowyinc_gotrue.build";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              # Health Check
              # healthCmd = "curl --fail http://127.0.0.1:9999/health || exit 1";
              # healthInterval = "5s";
              # healthTimeout = "5s";
              # healthRetries = 12;

              environment = {
                GOTRUE_ADMIN_EMAIL = "admin@example.com";
                GOTRUE_ADMIN_PASSWORD = "securepassword";
                GOTRUE_DISABLE_SIGNUP = "false";
                GOTRUE_SITE_URL = "appflowy-flutter://";
                GOTRUE_URI_ALLOW_LIST = "**";
                GOTRUE_JWT_SECRET = "defaultsecret";
                GOTRUE_JWT_EXP = "3600";
                GOTRUE_JWT_ADMIN_GROUP_NAME = "supabase_admin";
                GOTRUE_DB_DRIVER = "postgres";
                API_EXTERNAL_URL = "http://localhost:8080";
                DATABASE_URL = "postgres://postgres:password@localhost:5432/postgres";
                PORT = "9999";
                GOTRUE_SMTP_HOST = "smtp.example.com";
                GOTRUE_SMTP_PORT = "587";
                GOTRUE_SMTP_USER = "noreply@example.com";
                GOTRUE_SMTP_PASS = "smtpsecurepassword";
                GOTRUE_MAILER_URLPATHS_CONFIRMATION = "/gotrue/verify";
                GOTRUE_MAILER_URLPATHS_INVITE = "/gotrue/verify";
                GOTRUE_MAILER_URLPATHS_RECOVERY = "/gotrue/verify";
                GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE = "/gotrue/verify";
                GOTRUE_MAILER_TEMPLATES_MAGIC_LINK = "default_magic_link_template";
                GOTRUE_SMTP_ADMIN_EMAIL = "admin@example.com";
                GOTRUE_SMTP_MAX_FREQUENCY = "1ns";
                GOTRUE_RATE_LIMIT_EMAIL_SENT = "100";
                GOTRUE_MAILER_AUTOCONFIRM = "false";
              };
            };

            services.podman.containers.appflowy_cloud = {
              autoStart = true;
              extraConfig = {

                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
                Unit = {
                  After = "gotrue.container";
                  Requires = "gotrue.container";
                };
              };
              image = "appflowy_cloud_build.build";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              # Health Check
              # healthCmd = "curl --fail http://127.0.0.1:9999/health || exit 1";
              # healthInterval = "5s";
              # healthTimeout = "5s";
              # healthRetries = 12;

              environment = {
                RUST_LOG = "info";
                APPFLOWY_ENVIRONMENT = "production";
                APPFLOWY_DATABASE_URL = "APPFLOWY_DATABASE_URL";
                APPFLOWY_REDIS_URI = "APPFLOWY_REDIS_URI";
                APPFLOWY_GOTRUE_JWT_SECRET = "GOTRUE_JWT_SECRET";
                APPFLOWY_GOTRUE_JWT_EXP = "GOTRUE_JWT_EXP";
                APPFLOWY_GOTRUE_BASE_URL = "APPFLOWY_GOTRUE_BASE_URL";
                APPFLOWY_S3_CREATE_BUCKET = "APPFLOWY_S3_CREATE_BUCKET";
                APPFLOWY_S3_USE_MINIO = "APPFLOWY_S3_USE_MINIO";
                APPFLOWY_S3_MINIO_URL = "APPFLOWY_S3_MINIO_URL";
                APPFLOWY_S3_ACCESS_KEY = "minioadmin";
                APPFLOWY_S3_SECRET_KEY = "minioadmin";
              };

            };

            services.podman.containers.admin_frontend = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
                Unit = {
                  After = [
                    "gotrue.container"
                    "appflowy_cloud.container"
                  ];
                  Requires = [
                    "gotrue.container"
                    "appflowy_cloud.container"
                  ];
                };
              };

              image = "admin_frontend_build.build";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              environment = {
                RUST_LOG = "info";
                ADMIN_FRONTEND_REDIS_URL = "redis://redis:6379";
                ADMIN_FRONTEND_GOTRUE_URL = "http://gotrue:9999";
                ADMIN_FRONTEND_APPFLOWY_CLOUD_URL = "http://appflowy_cloud:8000";
                ADMIN_FRONTEND_PATH_PREFIX = "/";
              };
            };

            services.podman.containers.ai = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
                Unit = {
                  After = "postgres.container";
                  Requires = "postgres.container";
                };
              };

              image = "appflowyinc/appflowy_ai:latest";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              environment = {
                OPENAI_API_KEY = builtins.getEnv "AI_OPENAI_API_KEY";
                APPFLOWY_AI_SERVER_PORT = "8080";
              };
            };

            services.podman.containers.appflowy_worker = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
                Unit = {
                  After = "postgres.container";
                  Requires = "postgres.container";
                };
              };

              image = "appflowy_worker_build.build";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];

              environment = {
                RUST_LOG = "info";
                APPFLOWY_ENVIRONMENT = "production";
                APPFLOWY_WORKER_REDIS_URL = "redis://redis:6379";
                APPFLOWY_WORKER_ENVIRONMENT = "production";
                APPFLOWY_WORKER_IMPORT_TICK_INTERVAL = "30";
                APPFLOWY_S3_ACCESS_KEY = "minioadmin";
                APPFLOWY_S3_SECRET_KEY = "minioadmin";
              };
            };

            services.podman.containers.appflowy_web = {
              autoStart = true;
              extraConfig = {
                Service = {
                  RestartSec = "10";
                  Restart = "on-failure";
                };
                Unit = {
                  After = "appflowy_cloud.container";
                  Requires = "appflowy_cloud.container";
                };
              };

              image = "appflowyinc/appflowy_web:latest";

              extraPodmanArgs = [
                "--pod"
                "appflowy_pod"
              ];
              environmentFile = [
                "/home/joonas/Documents/git-projects/nix-podman-quadlet-collection/appflowy/AppFlowy-Cloud/.env"
              ];
            };

          };
        };
    };
}
