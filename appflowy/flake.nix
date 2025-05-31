# Nix-podman-appflowy-quadlet
{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    outputs =
    { nixpkgs, self, ... }@attrs:
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
                   
                    services.podman.builds = {
                        appflowyinc_gotrue = {
                            file = "${self}/AppFlowy-Cloud/docker/gotrue/Dockerfile";
                            tags = [ "homemanager:appflowyinc_gotrue" ];
                            extraPodmanArgs = [ "--env-file" "${self}/AppFlowy-Cloud/.env" ];
                            
                        };
                        
                        admin_frontend_build = {
                            file = "${self}/AppFlowy-Cloud/admin_frontend/Dockerfile";
                            tags = [ "localhost:admin_frontend_build" ];
                            workingDirectory = "/home/joonas/tempo";
                        };

                        appflowy_worker_build = {
                            file = "${self}/AppFlowy-Cloud/services/appflowy-worker/Dockerfile";
                            tags = [ "homemanager:appflowy_worker_build" ];
                        };

                        appflowy_cloud_build = {
                            file = "${self}/AppFlowy-Cloud/Dockerfile";
                            tags = [ "homemanager:appflowy_cloud_build" ];
                            # annotations = [ "FEATURES=" ];
                        };
                    };


                    services.podman.containers = {
                        
                        minio = {
                            autoStart = true;
                            extraConfig = {
                                Service = 
                                {
                                    Restart = "on-failure";
                                    RestartSec = "10";
                                };
                            };

                            image = "minio/minio";
                            extraPodmanArgs = [ "--pod" "appflowy_pod" ];
                            exec = "server /data --console-address :9001";

                            environment = {
                                MINIO_BROWSER_REDIRECT_URL = builtins.getEnv "APPFLOWY_BASE_URL";
                                MINIO_ROOT_USER = let
                                    s3Key = builtins.getEnv "APPFLOWY_S3_ACCESS_KEY";
                                in if s3Key != "" then s3Key else "minioadmin";
                                
                                MINIO_ROOT_PASSWORD = let
                                    s3Secret = builtins.getEnv "APPFLOWY_S3_SECRET_KEY";
                                in if s3Secret != "" then s3Secret else "minioadmin";

                            };

                            volumes = [
                                "/var/lib/containers/appflowy/minio_data:/data"
                            ];
                            
                        };
                    };

                    services.podman.containers.postgres = {
                        autoStart = true;
                        extraConfig = {
                            Service = 
                            {
                                RestartSec = "10";
                                Restart = "on-failure";
                            };
                        };
                        image = "pgvector/pgvector:pg16";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];
                        
                        environment = {
                            POSTGRES_USER = let user = builtins.getEnv "POSTGRES_USER"; in if user != "" then user else "postgres";
                            POSTGRES_DB = let db = builtins.getEnv "POSTGRES_DB"; in if db != "" then db else "postgres";
                            POSTGRES_PASSWORD = let pass = builtins.getEnv "POSTGRES_PASSWORD"; in if pass != "" then pass else "password";
                            POSTGRES_HOST = let host = builtins.getEnv "POSTGRES_HOST"; in if host != "" then host else "postgres";
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
                            Service = 
                            {
                                RestartSec = "10";
                                Restart = "on-failure";
                            };
                        };
                        image = "redis";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];
                    };

                    services.podman.containers.gotrue = {
                        autoStart = true;
                        extraConfig = {
                            Service = 
                            {
                                RestartSec = "10";
                                Restart = "on-failure";
                            };
                            Unit = {
                                After = "postgres.container";
                                Requires = "postgres.container";
                            };
                        };
                        image = "appflowyinc_gotrue.build";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];

                        # Health Check
                        # healthCmd = "curl --fail http://127.0.0.1:9999/health || exit 1";
                        # healthInterval = "5s";
                        # healthTimeout = "5s";
                        # healthRetries = 12;

                        environment = {
                            GOTRUE_ADMIN_EMAIL = let email = builtins.getEnv "GOTRUE_ADMIN_EMAIL"; in if email != "" then email else "admin@example.com";
                            GOTRUE_ADMIN_PASSWORD = let pass = builtins.getEnv "GOTRUE_ADMIN_PASSWORD"; in if pass != "" then pass else "securepassword";
                            GOTRUE_DISABLE_SIGNUP = let signup = builtins.getEnv "GOTRUE_DISABLE_SIGNUP"; in if signup != "" then signup else "false";
                            GOTRUE_SITE_URL = "appflowy-flutter://";
                            GOTRUE_URI_ALLOW_LIST = "**";
                            GOTRUE_JWT_SECRET = let jwtSecret = builtins.getEnv "GOTRUE_JWT_SECRET"; in if jwtSecret != "" then jwtSecret else "defaultsecret";
                            GOTRUE_JWT_EXP = let jwtExp = builtins.getEnv "GOTRUE_JWT_EXP"; in if jwtExp != "" then jwtExp else "3600";
                            GOTRUE_JWT_ADMIN_GROUP_NAME = "supabase_admin";
                            GOTRUE_DB_DRIVER = "postgres";
                            API_EXTERNAL_URL = let apiUrl = builtins.getEnv "API_EXTERNAL_URL"; in if apiUrl != "" then apiUrl else "http://localhost:8080";
                            DATABASE_URL = let dbUrl = builtins.getEnv "GOTRUE_DATABASE_URL"; in if dbUrl != "" then dbUrl else "postgres://user:password@localhost:5432/dbname";
                            PORT = "9999";
                            GOTRUE_SMTP_HOST = let smtpHost = builtins.getEnv "GOTRUE_SMTP_HOST"; in if smtpHost != "" then smtpHost else "smtp.example.com";
                            GOTRUE_SMTP_PORT = let smtpPort = builtins.getEnv "GOTRUE_SMTP_PORT"; in if smtpPort != "" then smtpPort else "587";
                            GOTRUE_SMTP_USER = let smtpUser = builtins.getEnv "GOTRUE_SMTP_USER"; in if smtpUser != "" then smtpUser else "noreply@example.com";
                            GOTRUE_SMTP_PASS = let smtpPass = builtins.getEnv "GOTRUE_SMTP_PASS"; in if smtpPass != "" then smtpPass else "smtpsecurepassword";
                            GOTRUE_MAILER_URLPATHS_CONFIRMATION = "/gotrue/verify";
                            GOTRUE_MAILER_URLPATHS_INVITE = "/gotrue/verify";
                            GOTRUE_MAILER_URLPATHS_RECOVERY = "/gotrue/verify";
                            GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE = "/gotrue/verify";
                            GOTRUE_MAILER_TEMPLATES_MAGIC_LINK = let magicLink = builtins.getEnv "GOTRUE_MAILER_TEMPLATES_MAGIC_LINK"; in if magicLink != "" then magicLink else "default_magic_link_template";
                            GOTRUE_SMTP_ADMIN_EMAIL = let smtpAdmin = builtins.getEnv "GOTRUE_SMTP_ADMIN_EMAIL"; in if smtpAdmin != "" then smtpAdmin else "admin@example.com";
                            GOTRUE_SMTP_MAX_FREQUENCY = let smtpMaxFreq = builtins.getEnv "GOTRUE_SMTP_MAX_FREQUENCY"; in if smtpMaxFreq != "" then smtpMaxFreq else "1ns";
                            GOTRUE_RATE_LIMIT_EMAIL_SENT = let rateLimit = builtins.getEnv "GOTRUE_RATE_LIMIT_EMAIL_SENT"; in if rateLimit != "" then rateLimit else "100";
                            GOTRUE_MAILER_AUTOCONFIRM = let autoConfirm = builtins.getEnv "GOTRUE_MAILER_AUTOCONFIRM"; in if autoConfirm != "" then autoConfirm else "false";
                            GOTRUE_EXTERNAL_GOOGLE_ENABLED = builtins.getEnv "GOTRUE_EXTERNAL_GOOGLE_ENABLED";
                            GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID = builtins.getEnv "GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID";
                            GOTRUE_EXTERNAL_GOOGLE_SECRET = builtins.getEnv "GOTRUE_EXTERNAL_GOOGLE_SECRET";
                            GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI = builtins.getEnv "GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI";
                            GOTRUE_EXTERNAL_GITHUB_ENABLED = builtins.getEnv "GOTRUE_EXTERNAL_GITHUB_ENABLED";
                            GOTRUE_EXTERNAL_GITHUB_CLIENT_ID = builtins.getEnv "GOTRUE_EXTERNAL_GITHUB_CLIENT_ID";
                            GOTRUE_EXTERNAL_GITHUB_SECRET = builtins.getEnv "GOTRUE_EXTERNAL_GITHUB_SECRET";
                            GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI = builtins.getEnv "GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI";
                            GOTRUE_EXTERNAL_DISCORD_ENABLED = builtins.getEnv "GOTRUE_EXTERNAL_DISCORD_ENABLED";
                            GOTRUE_EXTERNAL_DISCORD_CLIENT_ID = builtins.getEnv "GOTRUE_EXTERNAL_DISCORD_CLIENT_ID";
                            GOTRUE_EXTERNAL_DISCORD_SECRET = builtins.getEnv "GOTRUE_EXTERNAL_DISCORD_SECRET";
                            GOTRUE_EXTERNAL_DISCORD_REDIRECT_URI = builtins.getEnv "GOTRUE_EXTERNAL_DISCORD_REDIRECT_URI";
                            GOTRUE_SAML_ENABLED = builtins.getEnv "GOTRUE_SAML_ENABLED";
                            GOTRUE_SAML_PRIVATE_KEY = builtins.getEnv "GOTRUE_SAML_PRIVATE_KEY";
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
                        image = "appflowy_cloud_build";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];

                        # Health Check
                        # healthCmd = "curl --fail http://127.0.0.1:9999/health || exit 1";
                        # healthInterval = "5s";
                        # healthTimeout = "5s";
                        # healthRetries = 12;

                        environment = {
                            RUST_LOG = let log = builtins.getEnv "RUST_LOG"; in if log != "" then log else "info";
                            APPFLOWY_ENVIRONMENT = "production";
                            APPFLOWY_DATABASE_URL = builtins.getEnv "APPFLOWY_DATABASE_URL";
                            APPFLOWY_REDIS_URI = builtins.getEnv "APPFLOWY_REDIS_URI";
                            APPFLOWY_GOTRUE_JWT_SECRET = builtins.getEnv "GOTRUE_JWT_SECRET";
                            APPFLOWY_GOTRUE_JWT_EXP = builtins.getEnv "GOTRUE_JWT_EXP";
                            APPFLOWY_GOTRUE_BASE_URL = builtins.getEnv "APPFLOWY_GOTRUE_BASE_URL";
                            APPFLOWY_S3_CREATE_BUCKET = builtins.getEnv "APPFLOWY_S3_CREATE_BUCKET";
                            APPFLOWY_S3_USE_MINIO = builtins.getEnv "APPFLOWY_S3_USE_MINIO";
                            APPFLOWY_S3_MINIO_URL = builtins.getEnv "APPFLOWY_S3_MINIO_URL";
                            APPFLOWY_S3_ACCESS_KEY = let s3Key = builtins.getEnv "APPFLOWY_S3_ACCESS_KEY"; in if s3Key != "" then s3Key else "minioadmin";
                            APPFLOWY_S3_SECRET_KEY = let s3Secret = builtins.getEnv "APPFLOWY_S3_SECRET_KEY"; in if s3Secret != "" then s3Secret else "minioadmin";
                            APPFLOWY_S3_BUCKET = builtins.getEnv "APPFLOWY_S3_BUCKET";
                            APPFLOWY_S3_REGION = builtins.getEnv "APPFLOWY_S3_REGION";
                            APPFLOWY_S3_PRESIGNED_URL_ENDPOINT = builtins.getEnv "APPFLOWY_S3_PRESIGNED_URL_ENDPOINT";
                            APPFLOWY_MAILER_SMTP_HOST = builtins.getEnv "APPFLOWY_MAILER_SMTP_HOST";
                            APPFLOWY_MAILER_SMTP_PORT = builtins.getEnv "APPFLOWY_MAILER_SMTP_PORT";
                            APPFLOWY_MAILER_SMTP_USERNAME = builtins.getEnv "APPFLOWY_MAILER_SMTP_USERNAME";
                            APPFLOWY_MAILER_SMTP_EMAIL = builtins.getEnv "APPFLOWY_MAILER_SMTP_EMAIL";
                            APPFLOWY_MAILER_SMTP_PASSWORD = builtins.getEnv "APPFLOWY_MAILER_SMTP_PASSWORD";
                            APPFLOWY_MAILER_SMTP_TLS_KIND = builtins.getEnv "APPFLOWY_MAILER_SMTP_TLS_KIND";
                            APPFLOWY_ACCESS_CONTROL = builtins.getEnv "APPFLOWY_ACCESS_CONTROL";
                            APPFLOWY_DATABASE_MAX_CONNECTIONS = builtins.getEnv "APPFLOWY_DATABASE_MAX_CONNECTIONS";
                            AI_SERVER_HOST = builtins.getEnv "AI_SERVER_HOST";
                            AI_SERVER_PORT = builtins.getEnv "AI_SERVER_PORT";
                            AI_OPENAI_API_KEY = builtins.getEnv "AI_OPENAI_API_KEY";
                            APPFLOWY_WEB_URL = builtins.getEnv "APPFLOWY_WEB_URL";
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
                                After = [ "gotrue.container" "appflowy_cloud.container" ];
                                Requires = [ "gotrue.container" "appflowy_cloud.container" ];
                            };
                        };

                        image = "admin_frontend_build";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];

                        environment = {
                            RUST_LOG = let log = builtins.getEnv "RUST_LOG"; in if log != "" then log else "info";
                            ADMIN_FRONTEND_REDIS_URL = let redisUrl = builtins.getEnv "ADMIN_FRONTEND_REDIS_URL"; in if redisUrl != "" then redisUrl else "redis://redis:6379";
                            ADMIN_FRONTEND_GOTRUE_URL = let gotrueUrl = builtins.getEnv "ADMIN_FRONTEND_GOTRUE_URL"; in if gotrueUrl != "" then gotrueUrl else "http://gotrue:9999";
                            ADMIN_FRONTEND_APPFLOWY_CLOUD_URL = let cloudUrl = builtins.getEnv "ADMIN_FRONTEND_APPFLOWY_CLOUD_URL"; in if cloudUrl != "" then cloudUrl else "http://appflowy_cloud:8000";
                            ADMIN_FRONTEND_PATH_PREFIX = let pathPrefix = builtins.getEnv "ADMIN_FRONTEND_PATH_PREFIX"; in if pathPrefix != "" then pathPrefix else "/";
                        };
                    };


                    #services.podman.containers.ai = {
                    #    autoStart = true;
                    #    extraConfig = {
                    #        Service = {
                    #            RestartSec = "10";
                    #            Restart = "on-failure";
                    #        };
                    #        Unit = {
                    #            After = "postgres.container";
                    #            Requires = "postgres.container";
                    #        };
                    #    };

                    
                    #    image = let aiVersion = builtins.getEnv "APPFLOWY_AI_VERSION"; in "appflowyinc/appflowy_ai:${if aiVersion != "" then aiVersion else "latest"}";
                    #    extraPodmanArgs = [ "--pod" "appflowy_pod" ];

                        
                    #    environment = {
                    #        OPENAI_API_KEY = builtins.getEnv "AI_OPENAI_API_KEY";
                    #        APPFLOWY_AI_SERVER_PORT = let port = builtins.getEnv "AI_SERVER_PORT"; in if port != "" then port else "8080";
                    #        APPFLOWY_AI_DATABASE_URL = builtins.getEnv "AI_DATABASE_URL";
                    #        APPFLOWY_AI_REDIS_URL = builtins.getEnv "AI_REDIS_URL";
                    #    };
                    #};


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

                        image = "appflowy_worker_build";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];

                        environment = {
                            RUST_LOG = let log = builtins.getEnv "RUST_LOG"; in if log != "" then log else "info";
                            APPFLOWY_ENVIRONMENT = "production";
                            APPFLOWY_WORKER_REDIS_URL = let redisUrl = builtins.getEnv "APPFLOWY_WORKER_REDIS_URL"; in if redisUrl != "" then redisUrl else "redis://redis:6379";
                            APPFLOWY_WORKER_ENVIRONMENT = "production";
                            APPFLOWY_WORKER_DATABASE_URL = builtins.getEnv "APPFLOWY_WORKER_DATABASE_URL";
                            APPFLOWY_WORKER_DATABASE_NAME = builtins.getEnv "APPFLOWY_WORKER_DATABASE_NAME";
                            APPFLOWY_WORKER_IMPORT_TICK_INTERVAL = let tickInterval = builtins.getEnv "APPFLOWY_WORKER_IMPORT_TICK_INTERVAL"; in if tickInterval != "" then tickInterval else "30";
                            APPFLOWY_S3_USE_MINIO = builtins.getEnv "APPFLOWY_S3_USE_MINIO";
                            APPFLOWY_S3_MINIO_URL = builtins.getEnv "APPFLOWY_S3_MINIO_URL";
                            APPFLOWY_S3_ACCESS_KEY = let s3Key = builtins.getEnv "APPFLOWY_S3_ACCESS_KEY"; in if s3Key != "" then s3Key else "minioadmin";
                            APPFLOWY_S3_SECRET_KEY = let s3Secret = builtins.getEnv "APPFLOWY_S3_SECRET_KEY"; in if s3Secret != "" then s3Secret else "minioadmin";
                            APPFLOWY_S3_BUCKET = builtins.getEnv "APPFLOWY_S3_BUCKET";
                            APPFLOWY_S3_REGION = builtins.getEnv "APPFLOWY_S3_REGION";
                            APPFLOWY_MAILER_SMTP_HOST = builtins.getEnv "APPFLOWY_MAILER_SMTP_HOST";
                            APPFLOWY_MAILER_SMTP_PORT = builtins.getEnv "APPFLOWY_MAILER_SMTP_PORT";
                            APPFLOWY_MAILER_SMTP_USERNAME = builtins.getEnv "APPFLOWY_MAILER_SMTP_USERNAME";
                            APPFLOWY_MAILER_SMTP_EMAIL = builtins.getEnv "APPFLOWY_MAILER_SMTP_EMAIL";
                            APPFLOWY_MAILER_SMTP_PASSWORD = builtins.getEnv "APPFLOWY_MAILER_SMTP_PASSWORD";
                            APPFLOWY_MAILER_SMTP_TLS_KIND = builtins.getEnv "APPFLOWY_MAILER_SMTP_TLS_KIND";
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

                        
                        image = let webVersion = builtins.getEnv "APPFLOWY_WEB_VERSION"; in "appflowyinc/appflowy_web:''${if webVersion != "" then webVersion else "latest"}''";
                        extraPodmanArgs = [ "--pod" "appflowy_pod" ];
                    };





                        };
                    };
                };
}
