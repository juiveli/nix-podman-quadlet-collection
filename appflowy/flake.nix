# Nix-podman-appflowy-quadlet
{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    outputs =
    { nixpkgs, ... }@attrs:
        {

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
                    systemd.user.startServices = "sd-switch";

                        virtualisation.quadlet = let
        inherit (config.virtualisation.quadlet) networks pods builds;

        
                  in {

                      pods = {
                          appflowy_pod = { };
                      };

                      builds = {
                      appflowyinc_gotrue = {

                        buildConfig = {
                          file = "./AppFlowy-Cloud/docker/gotrue/Dockerfile";
                          tag = "appflowyinc_gotrue";
                        };
                      };

                      admin_frontend_build = {
                        buildConfig = {
                          file = "./AppFlowy-Cloud/admin_frontend/Dockerfile";
                          tag = "admin_frontend_build";
                            };
                          };

                      appflowy_worker_build = {
                        buildConfig = {
                          file = "./AppFlowy-Cloud/services/appflowy-worker/Dockerfile";
                          tag = "appflowy_worker_build";
                            };
                          };

                      appflowy_cloud_build = {
                        buildConfig = {
                        file = "./AppFlowy-Cloud/Dockerfile";
                        tag = "appflowy_cloud_build";
                        
                        annotations = [
                            "FEATURES="
                          ];
                        };
                      };

                      };

                      containers = {

                          minio = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";
                              };
                              containerConfig = {
                                  image = "minio/minio";
                                  pod = pods.appflowy_pod.ref;
                                  exec = [ "server" "/data" "--console-address" ":9001" ];

                                  environments = {
                                      MINIO_BROWSER_REDIRECT_URL=''''${APPFLOWY_BASE_URL}/minio'';
                                      MINIO_ROOT_USER=''''${APPFLOWY_S3_ACCESS_KEY:-minioadmin}'';
                                      MINIO_ROOT_PASSWORD=''''${APPFLOWY_S3_SECRET_KEY:-minioadmin}'';
                                  };

                              volumes = [
                                  "/var/lib/containers/appflowy/minio_data:/data"
                                  ];
                              };
                          };

                          postgres = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";
                              };
                              containerConfig = {
                                  image = "pgvector/pgvector:pg16";
                                  pod = pods.appflowy_pod.ref;
                                  # healthCmd = ''''CMD'',pg_isready'',-U'',''${POSTGRES_USER}'',-d'',''${POSTGRES_DB}'';
                                  # healthInterval = "5s";
                                  # healthTimeout = "5s";
                                  # healthRetries = 12;
                                  
                                  environments = {
                                      POSTGRES_USER=''''${POSTGRES_USER:-postgres}'';
                                      POSTGRES_DB=''''${POSTGRES_DB:-postgres}'';
                                      POSTGRES_PASSWORD=''''${POSTGRES_PASSWORD:-password}'';
                                      POSTGRES_HOST=''''${POSTGRES_HOST:-postgres}'';
                                  };

                              volumes = [
                                  "var/lib/containers/appflowy/postgres_data:/var/lib/postgresql/data"
                                  ];
                              };
                          };

                          redis = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";
                              };
                              containerConfig = {
                                  image = "redis";
                                  pod = pods.appflowy_pod.ref;
                              };
                          };

                          gotrue = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";
                              };

                              unitConfig = {
                                  After = "postgres.container";
                                  Requires = "postgres.container";
                              };

                              containerConfig = {
                                  image = "appflowyinc_gotrue";
                                  pod = pods.appflowy_pod.ref;
                                  healthCmd = "curl --fail http://127.0.0.1:9999/health || exit 1";
                                  healthInterval = "5s";
                                  healthTimeout = "5s";
                                  healthRetries = 12;

                                  environments = {
                                      # There are a lot of options to configure GoTrue. You can reference the example config:
                                      # https://github.com/supabase/auth/blob/master/example.env
                                      # The initial GoTrue Admin user to create, if not already exists.
                                      GOTRUE_ADMIN_EMAIL=''''${GOTRUE_ADMIN_EMAIL}'';
                                      # The initial GoTrue Admin user password to create, if not already exists.
                                      # If the user already exists, the update will be skipped.
                                      GOTRUE_ADMIN_PASSWORD=''''${GOTRUE_ADMIN_PASSWORD}'';
                                      GOTRUE_DISABLE_SIGNUP=''''${GOTRUE_DISABLE_SIGNUP:-false}'';
                                      GOTRUE_SITE_URL="appflowy-flutter://";                           # redirected to AppFlowy application
                                      GOTRUE_URI_ALLOW_LIST="**"; # adjust restrict if necessary
                                      GOTRUE_JWT_SECRET=''''${GOTRUE_JWT_SECRET}'';                        # authentication secret
                                      GOTRUE_JWT_EXP=''''${GOTRUE_JWT_EXP}'';
                                      # Without this environment variable, the createuser command will create an admin
                                      # with the `admin` role as opposed to `supabase_admin`
                                      GOTRUE_JWT_ADMIN_GROUP_NAME="supabase_admin";
                                      GOTRUE_DB_DRIVER="postgres";
                                      API_EXTERNAL_URL=''''${API_EXTERNAL_URL}'';
                                      DATABASE_URL=''''${GOTRUE_DATABASE_URL}'';
                                      PORT="9999";
                                      GOTRUE_SMTP_HOST=''''${GOTRUE_SMTP_HOST}'';                          # e.g. smtp.gmail.com
                                      GOTRUE_SMTP_PORT=''''${GOTRUE_SMTP_PORT}'';                          # e.g. 465
                                      GOTRUE_SMTP_USER=''''${GOTRUE_SMTP_USER}'';                          # email sender, e.g. noreply@appflowy.io
                                      GOTRUE_SMTP_PASS=''''${GOTRUE_SMTP_PASS}'';                          # email password
                                      GOTRUE_MAILER_URLPATHS_CONFIRMATION="/gotrue/verify";
                                      GOTRUE_MAILER_URLPATHS_INVITE="/gotrue/verify";
                                      GOTRUE_MAILER_URLPATHS_RECOVERY="/gotrue/verify";
                                      GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE="/gotrue/verify";
                                      GOTRUE_MAILER_TEMPLATES_MAGIC_LINK=''''${GOTRUE_MAILER_TEMPLATES_MAGIC_LINK}'';
                                      GOTRUE_SMTP_ADMIN_EMAIL=''''${GOTRUE_SMTP_ADMIN_EMAIL}'';                # email with admin privileges e.g. internal@appflowy.io
                                      GOTRUE_SMTP_MAX_FREQUENCY=''''${GOTRUE_SMTP_MAX_FREQUENCY:-1ns}'';       # set to 1ns for running tests
                                      GOTRUE_RATE_LIMIT_EMAIL_SENT=''''${GOTRUE_RATE_LIMIT_EMAIL_SENT:-100}''; # number of email sendable per minute
                                      GOTRUE_MAILER_AUTOCONFIRM=''''${GOTRUE_MAILER_AUTOCONFIRM:-false}'';     # change this to true to skip email confirmation
                                      # Google OAuth config
                                      GOTRUE_EXTERNAL_GOOGLE_ENABLED=''''${GOTRUE_EXTERNAL_GOOGLE_ENABLED}'';
                                      GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=''''${GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID}'';
                                      GOTRUE_EXTERNAL_GOOGLE_SECRET=''''${GOTRUE_EXTERNAL_GOOGLE_SECRET}'';
                                      GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=''''${GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI}'';
                                      # GITHUB OAuth config
                                      GOTRUE_EXTERNAL_GITHUB_ENABLED=''''${GOTRUE_EXTERNAL_GITHUB_ENABLED}'';
                                      GOTRUE_EXTERNAL_GITHUB_CLIENT_ID=''''${GOTRUE_EXTERNAL_GITHUB_CLIENT_ID}'';
                                      GOTRUE_EXTERNAL_GITHUB_SECRET=''''${GOTRUE_EXTERNAL_GITHUB_SECRET}'';
                                      GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI=''''${GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI}'';
                                      # Discord OAuth config
                                      GOTRUE_EXTERNAL_DISCORD_ENABLED=''''${GOTRUE_EXTERNAL_DISCORD_ENABLED}'';
                                      GOTRUE_EXTERNAL_DISCORD_CLIENT_ID=''''${GOTRUE_EXTERNAL_DISCORD_CLIENT_ID}'';
                                      GOTRUE_EXTERNAL_DISCORD_SECRET=''''${GOTRUE_EXTERNAL_DISCORD_SECRET}'';
                                      GOTRUE_EXTERNAL_DISCORD_REDIRECT_URI=''''${GOTRUE_EXTERNAL_DISCORD_REDIRECT_URI}'';
                                      # SAML 2.0 OAuth config
                                      GOTRUE_SAML_ENABLED=''''${GOTRUE_SAML_ENABLED}'';
                                      GOTRUE_SAML_PRIVATE_KEY=''''${GOTRUE_SAML_PRIVATE_KEY}'';

                                  };
                              };
                          };

                          appflowy_cloud = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";
                              };

                              unitConfig = {
                                  After = "gotrue.container";
                                  Requires = "gotrue.container";
                              };

                              containerConfig = {
                                  image = "appflowy_cloud_build";
                                  pod = pods.appflowy_pod.ref;
                                  healthCmd = "curl --fail http://127.0.0.1:9999/health || exit 1";
                                  healthInterval = "5s";
                                  healthTimeout = "5s";
                                  healthRetries = 12;

                                  environments = {
                                      RUST_LOG=''''${RUST_LOG:-info}'';
                                      APPFLOWY_ENVIRONMENT="production";
                                      APPFLOWY_DATABASE_URL=''''${APPFLOWY_DATABASE_URL}'';
                                      APPFLOWY_REDIS_URI=''''${APPFLOWY_REDIS_URI}'';
                                      APPFLOWY_GOTRUE_JWT_SECRET=''''${GOTRUE_JWT_SECRET}'';
                                      APPFLOWY_GOTRUE_JWT_EXP=''''${GOTRUE_JWT_EXP}'';
                                      APPFLOWY_GOTRUE_BASE_URL=''''${APPFLOWY_GOTRUE_BASE_URL}'';
                                      APPFLOWY_S3_CREATE_BUCKET=''''${APPFLOWY_S3_CREATE_BUCKET}'';
                                      APPFLOWY_S3_USE_MINIO=''''${APPFLOWY_S3_USE_MINIO}'';
                                      APPFLOWY_S3_MINIO_URL=''''${APPFLOWY_S3_MINIO_URL}'';
                                      APPFLOWY_S3_ACCESS_KEY=''''${APPFLOWY_S3_ACCESS_KEY}'';
                                      APPFLOWY_S3_SECRET_KEY=''''${APPFLOWY_S3_SECRET_KEY}'';
                                      APPFLOWY_S3_BUCKET=''''${APPFLOWY_S3_BUCKET}'';
                                      APPFLOWY_S3_REGION=''''${APPFLOWY_S3_REGION}'';
                                      APPFLOWY_S3_PRESIGNED_URL_ENDPOINT=''''${APPFLOWY_S3_PRESIGNED_URL_ENDPOINT}'';
                                      APPFLOWY_MAILER_SMTP_HOST=''''${APPFLOWY_MAILER_SMTP_HOST}'';
                                      APPFLOWY_MAILER_SMTP_PORT=''''${APPFLOWY_MAILER_SMTP_PORT}'';
                                      APPFLOWY_MAILER_SMTP_USERNAME=''''${APPFLOWY_MAILER_SMTP_USERNAME}'';
                                      APPFLOWY_MAILER_SMTP_EMAIL=''''${APPFLOWY_MAILER_SMTP_EMAIL}'';
                                      APPFLOWY_MAILER_SMTP_PASSWORD=''''${APPFLOWY_MAILER_SMTP_PASSWORD}'';
                                      APPFLOWY_MAILER_SMTP_TLS_KIND=''''${APPFLOWY_MAILER_SMTP_TLS_KIND}'';
                                      APPFLOWY_ACCESS_CONTROL=''''${APPFLOWY_ACCESS_CONTROL}'';
                                      APPFLOWY_DATABASE_MAX_CONNECTIONS=''''${APPFLOWY_DATABASE_MAX_CONNECTIONS}'';
                                      AI_SERVER_HOST=''''${AI_SERVER_HOST}'';
                                      AI_SERVER_PORT=''''${AI_SERVER_PORT}'';
                                      AI_OPENAI_API_KEY=''''${AI_OPENAI_API_KEY}'';
                                      APPFLOWY_WEB_URL=''''${APPFLOWY_WEB_URL}'';
                                  };
                              };
                              



                          };

                          admin_frontend = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";    
                              };

                              containerConfig = {
                                  image = "admin_frontend_build";
                                  pod = pods.appflowy_pod.ref;

                                  environments = {
                                      RUST_LOG=''''${RUST_LOG:-info}'';
                                      ADMIN_FRONTEND_REDIS_URL=''''${ADMIN_FRONTEND_REDIS_URL:-redis://redis:6379}'';
                                      ADMIN_FRONTEND_GOTRUE_URL=''''${ADMIN_FRONTEND_GOTRUE_URL:-http://gotrue:9999}'';
                                      ADMIN_FRONTEND_APPFLOWY_CLOUD_URL=''''${ADMIN_FRONTEND_APPFLOWY_CLOUD_URL:-http://appflowy_cloud:8000}'';
                                      ADMIN_FRONTEND_PATH_PREFIX=''''${ADMIN_FRONTEND_PATH_PREFIX:-""}'';

                                  };

                              };
                              
                              unitConfig = {
                                  After = [ "gotrue.container" "appflowy_cloud.container" ];
                                  Requires = [ "gotrue.container" "appflowy_cloud.container" ];
                              };


                              
                          };


                          ai = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";    
                              };
                              containerConfig = {
                                  image = ''appflowyinc/appflowy_ai:''${APPFLOWY_AI_VERSION-"latest"}'';

                                                        
                                  pod = pods.appflowy_pod.ref;

                                  environments = {
                                      OPENAI_API_KEY=''''${AI_OPENAI_API_KEY}'';
                                      APPFLOWY_AI_SERVER_PORT=''''${AI_SERVER_PORT}'';
                                      APPFLOWY_AI_DATABASE_URL=''''${AI_DATABASE_URL}'';
                                      APPFLOWY_AI_REDIS_URL=''''${AI_REDIS_URL}'';
                                  };

                              };
                              
                              unitConfig = {
                                  After = "postgres.container";
                                  Requires = "postgres.container";
                              };
                          };

                          appflowy_worker = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";    
                              };
                              containerConfig = {
                                  image = "appflowy_worker_build";
                                  pod = pods.appflowy_pod.ref;

                                  environments = {
                                      RUST_LOG=''''${RUST_LOG:-info}'';
                                      APPFLOWY_ENVIRONMENT="production";
                                      APPFLOWY_WORKER_REDIS_URL=''''${APPFLOWY_WORKER_REDIS_URL:-redis://redis:6379}'';
                                      APPFLOWY_WORKER_ENVIRONMENT="production";
                                      APPFLOWY_WORKER_DATABASE_URL=''''${APPFLOWY_WORKER_DATABASE_URL}'';
                                      APPFLOWY_WORKER_DATABASE_NAME=''''${APPFLOWY_WORKER_DATABASE_NAME}'';
                                      APPFLOWY_WORKER_IMPORT_TICK_INTERVAL="30";
                                      APPFLOWY_S3_USE_MINIO=''''${APPFLOWY_S3_USE_MINIO}'';
                                      APPFLOWY_S3_MINIO_URL=''''${APPFLOWY_S3_MINIO_URL}'';
                                      APPFLOWY_S3_ACCESS_KEY=''''${APPFLOWY_S3_ACCESS_KEY}'';
                                      APPFLOWY_S3_SECRET_KEY=''''${APPFLOWY_S3_SECRET_KEY}'';
                                      APPFLOWY_S3_BUCKET=''''${APPFLOWY_S3_BUCKET}'';
                                      APPFLOWY_S3_REGION=''''${APPFLOWY_S3_REGION}'';
                                      APPFLOWY_MAILER_SMTP_HOST=''''${APPFLOWY_MAILER_SMTP_HOST}'';
                                      APPFLOWY_MAILER_SMTP_PORT=''''${APPFLOWY_MAILER_SMTP_PORT}'';
                                      APPFLOWY_MAILER_SMTP_USERNAME=''''${APPFLOWY_MAILER_SMTP_USERNAME}'';
                                      APPFLOWY_MAILER_SMTP_EMAIL=''''${APPFLOWY_MAILER_SMTP_EMAIL}'';
                                      APPFLOWY_MAILER_SMTP_PASSWORD=''''${APPFLOWY_MAILER_SMTP_PASSWORD}'';
                                      APPFLOWY_MAILER_SMTP_TLS_KIND=''''${APPFLOWY_MAILER_SMTP_TLS_KIND}'';
                                  };

                              };
                              
                              unitConfig = {
                                  After = "postgres.container";
                                  Requires = "postgres.container";
                              };
                            
                          };

                          appflowy_web = {
                              autoStart = true;
                              serviceConfig = {
                                  RestartSec = "10";
                                  Restart = "on-failure";    
                              };
                              containerConfig = {
                                  image = ''appflowyinc/appflowy_web:''${APPFLOWY_WEB_VERSION-"latest"}'';

                                  pod = pods.appflowy_pod.ref;

                              };
                              
                              unitConfig = {
                                  After = "appflowy_cloud.container";
                                  Requires = "appflowy_cloud.container";
                              };
                          };
                        };
                    };
                };

            };
        };
}
