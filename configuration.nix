{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "maelstrom";
  networking.hostId   = "4b3143a6";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable          = true;
    allowedTCPPorts = [ 80 443 ];
  };

  time.timeZone      = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  age.secrets = {
    paperlessAdminPassword  = { file = ./paperless-admin-password.age;  owner = "paperless"; };
    paperlessSecretKey      = { file = ./paperless-secret-key.age;      owner = "paperless"; };
    vaultwardenAdminToken   = { file = ./vaultwarden-admin-token.age;   };
    vaultwardenSmtpPassword = { file = ./vaultwarden-smtp-password.age; };
    giteaSecretKey          = { file = ./gitea-secret-key.age;          owner = "gitea"; };
    giteaInternalToken      = { file = ./gitea-internal-token.age;      owner = "gitea"; };
    giteaJwtSecret          = { file = ./gitea-jwt-secret.age;          owner = "gitea"; };
    giteaSmtpPassword       = { file = ./gitea-smtp-password.age;       owner = "gitea"; };
    traefikTlsCert          = { file = ./traefik-tls-cert.age;          owner = "traefik"; path = "/run/traefik/tls.crt"; };
    traefikTlsKey           = { file = ./traefik-tls-key.age;           owner = "traefik"; path = "/run/traefik/tls.key"; mode = "0400"; };
    sendSecret              = { file = ./send-secret.age; };
    convertxJwtSecret       = { file = ./convertx-jwt-secret.age; };
    chiyogamiSecretKey      = { file = ./chiyogami-secret-key.age; };
    smtpUsername            = { file = ./smtp-username.age; };
    smtpPassword            = { file = ./smtp-password.age; };
  };

  services.postgresql = {
    enable   = true;
    package  = pkgs.postgresql_17;

    ensureDatabases = [ "paperless" "vaultwarden" "gitea" ];

    ensureUsers = [
      { name = "paperless";   ensureDBOwnership = true; }
      { name = "vaultwarden"; ensureDBOwnership = true; }
      { name = "gitea";       ensureDBOwnership = true; }
    ];

    settings.listen_addresses = "localhost";
  };

  services.redis.servers.maelstrom = {
    enable = true;
    port   = 6379;
    bind   = "127.0.0.1";
  };

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      log.level     = "INFO";
      accessLog     = true;
      api.dashboard = true;

      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = { to = "websecure"; scheme = "https"; };
        };
        websecure.address = ":443";
      };
    };

    dynamicConfigOptions = {
      tls.stores.default.defaultCertificate = {
        certFile = "/run/traefik/tls.crt";
        keyFile  = "/run/traefik/tls.key";
      };

      http = {
        routers = {
          traefik     = { rule = "Host(`traefik.home`)";     entryPoints = ["websecure"]; tls = {}; service = "api@internal"; };
          paperless   = { rule = "Host(`paperless.home`)";   entryPoints = ["websecure"]; tls = {}; service = "paperless"; };
          vaultwarden = { rule = "Host(`vaultwarden.home`)"; entryPoints = ["websecure"]; tls = {}; service = "vaultwarden"; };
          gitea       = { rule = "Host(`gitea.home`)";       entryPoints = ["websecure"]; tls = {}; service = "gitea"; };
          gatus       = { rule = "Host(`gatus.home`)";       entryPoints = ["websecure"]; tls = {}; service = "gatus"; };
          homepage    = { rule = "Host(`home.home`)";        entryPoints = ["websecure"]; tls = {}; service = "homepage"; };
          chiyogami   = { rule = "Host(`chiyogami.home`)";   entryPoints = ["websecure"]; tls = {}; service = "chiyogami"; };
          convertx    = { rule = "Host(`convertx.home`)";    entryPoints = ["websecure"]; tls = {}; service = "convertx"; };
          send        = { rule = "Host(`send.home`)";        entryPoints = ["websecure"]; tls = {}; service = "send"; };
        };

        services = {
          paperless.loadBalancer.servers   = [{ url = "http://127.0.0.1:28981"; }];
          vaultwarden.loadBalancer.servers  = [{ url = "http://127.0.0.1:8222"; }];
          gitea.loadBalancer.servers        = [{ url = "http://127.0.0.1:3001"; }];
          gatus.loadBalancer.servers        = [{ url = "http://127.0.0.1:8090"; }];
          homepage.loadBalancer.servers     = [{ url = "http://127.0.0.1:8082"; }];
          chiyogami.loadBalancer.servers    = [{ url = "http://127.0.0.1:8010"; }];
          convertx.loadBalancer.servers     = [{ url = "http://127.0.0.1:3000"; }];
          send.loadBalancer.servers         = [{ url = "http://127.0.0.1:1234"; }];
        };
      };
    };
  };

  systemd.services.traefik = {
    after  = [ "agenix.service" ];
    wants  = [ "agenix.service" ];
    serviceConfig.RuntimeDirectory = "traefik";
  };

  services.paperless = {
    enable         = true;
    dataDir        = "/mnt/data/paperless";
    mediaDir       = "/mnt/data/paperless/media";
    consumptionDir = "/mnt/data/paperless/consume";
    passwordFile   = config.age.secrets.paperlessAdminPassword.path;

    settings = {
      PAPERLESS_URL        = "https://paperless.home";
      PAPERLESS_TIME_ZONE  = "Europe/Paris";
      PAPERLESS_ADMIN_USER = "admin";
      PAPERLESS_DBHOST     = "/run/postgresql";
      PAPERLESS_DBNAME     = "paperless";
      PAPERLESS_DBUSER     = "paperless";
      PAPERLESS_REDIS      = "redis://127.0.0.1:6379";
      PAPERLESS_SECRET_KEY = config.age.secrets.paperlessSecretKey.path;
    };
  };

  services.vaultwarden = {
    enable = true;

    config = {
      DOMAIN          = "https://vaultwarden.home";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS  = "127.0.0.1";
      ROCKET_PORT     = 8222;
      ROCKET_LOG      = "critical";
      DATABASE_URL    = "postgresql://vaultwarden@localhost/vaultwarden?host=/run/postgresql";
      SMTP_PORT       = 587;
      SMTP_SECURITY   = "starttls";
    };
  };

  systemd.services.vaultwarden.serviceConfig.EnvironmentFile = [
    config.age.secrets.vaultwardenAdminToken.path
    config.age.secrets.vaultwardenSmtpPassword.path
    config.age.secrets.smtpUsername.path
    config.age.secrets.smtpPassword.path
  ];

  services.gitea = {
    enable   = true;
    stateDir = "/mnt/data/gitea";

    database = {
      type           = "postgres";
      socket         = "/run/postgresql";
      name           = "gitea";
      user           = "gitea";
      createDatabase = false;
    };

    settings = {
      server = {
        DOMAIN    = "gitea.home";
        ROOT_URL  = "https://gitea.home";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3001;
      };

      service.DISABLE_REGISTRATION = true;

      mailer = {
        ENABLED   = true;
        PROTOCOL  = "smtp+starttls";
        SMTP_PORT = 587;
      };

      security.INSTALL_LOCK = true;
    };

    secretFile = config.age.secrets.giteaSecretKey.path;
  };

  services.gatus = {
    enable = true;

    settings = {
      web.port     = 8090;
      storage.type = "memory";
      metrics      = true;

      endpoints = [
        { name = "Traefik";     url = "https://traefik.home";     interval = "1m"; conditions = [ "[STATUS] < 400" ]; }
        { name = "Paperless";   url = "https://paperless.home";   interval = "2m"; conditions = [ "[STATUS] == 200" ]; }
        { name = "Vaultwarden"; url = "https://vaultwarden.home"; interval = "2m"; conditions = [ "[STATUS] == 200" ]; }
        { name = "Gitea";       url = "https://gitea.home";       interval = "2m"; conditions = [ "[STATUS] == 200" ]; }
        { name = "Chiyogami";   url = "https://chiyogami.home";   interval = "2m"; conditions = [ "[STATUS] == 200" ]; }
        { name = "ConvertX";    url = "https://convertx.home";    interval = "5m"; conditions = [ "[STATUS] < 400" ]; }
        { name = "Send";        url = "https://send.home";        interval = "2m"; conditions = [ "[STATUS] == 200" ]; }
        { name = "Homepage";    url = "https://home.home";        interval = "5m"; conditions = [ "[STATUS] == 200" ]; }
      ];
    };
  };

  services.homepage-dashboard = {
    enable     = true;
    listenPort = 8082;

    settings = {
      title       = "maelstrom";
      theme       = "dark";
      color       = "slate";
      headerStyle = "clean";
      layout = {
        "Infrastructure" = { style = "row"; columns = 3; };
        "Files & Docs"   = { style = "row"; columns = 3; };
        "Dev"            = { style = "row"; columns = 3; };
        "Tools"          = { style = "row"; columns = 3; };
      };
    };

    services = [
      { "Infrastructure" = [
        { Traefik = { href = "https://traefik.home"; description = "Reverse proxy";     icon = "traefik.png"; }; }
        { Gatus   = { href = "https://gatus.home";   description = "Uptime monitoring"; icon = "gatus.png";   }; }
      ]; }
      { "Files & Docs" = [
        { Paperless = { href = "https://paperless.home"; description = "Document manager";  icon = "paperless-ngx.png"; }; }
        { Send      = { href = "https://send.home";      description = "Encrypted sharing"; icon = "send.png";          }; }
      ]; }
      { "Dev" = [
        { Gitea     = { href = "https://gitea.home";     description = "Git forge"; icon = "gitea.png";    }; }
        { Chiyogami = { href = "https://chiyogami.home"; description = "Pastebin";  icon = "pastebin.png"; }; }
      ]; }
      { "Tools" = [
        { Vaultwarden = { href = "https://vaultwarden.home"; description = "Password manager"; icon = "vaultwarden.png"; }; }
        { ConvertX    = { href = "https://convertx.home";    description = "File converter";   icon = "convertx.png";    }; }
      ]; }
    ];
  };

  systemd.services.chiyogami = {
    description = "Chiyogami pastebin";
    after       = [ "network.target" "agenix.service" ];
    wantedBy    = [ "multi-user.target" ];

    environment = {
      PORT     = "8010";
      DATA_DIR = "/mnt/data/chiyogami";
    };

    serviceConfig = {
      Type            = "simple";
      ExecStart       = "/opt/chiyogami/chiyogami";
      EnvironmentFile = config.age.secrets.chiyogamiSecretKey.path;
      WorkingDirectory = "/opt/chiyogami";
      DynamicUser     = true;

      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      PrivateTmp      = true;
      ReadWritePaths  = [ "/mnt/data/chiyogami" ];
    };
  };

  systemd.services.convertx = {
    description = "ConvertX file converter";
    after       = [ "network.target" "agenix.service" ];
    wantedBy    = [ "multi-user.target" ];

    environment = {
      PORT                  = "3000";
      ALLOW_UNAUTHENTICATED = "false";
      DATA_DIR              = "/mnt/data/convertx";
    };

    serviceConfig = {
      Type            = "simple";
      ExecStart       = "/opt/convertx/convertx";
      EnvironmentFile = config.age.secrets.convertxJwtSecret.path;
      DynamicUser     = true;

      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      PrivateTmp      = true;
      ReadWritePaths  = [ "/mnt/data/convertx" ];
    };
  };

  systemd.services.send = {
    description = "Send encrypted file sharing";
    after       = [ "network.target" "redis-maelstrom.service" "agenix.service" ];
    wants       = [ "redis-maelstrom.service" ];
    wantedBy    = [ "multi-user.target" ];

    environment = {
      NODE_ENV             = "production";
      BASE_URL             = "https://send.home";
      PORT                 = "1234";
      REDIS_HOST           = "127.0.0.1";
      REDIS_PORT           = "6379";
      FILE_DIR             = "/mnt/data/send/uploads";
      MAX_FILE_SIZE        = "2147483648";
      MAX_DOWNLOADS        = "20";
      EXPIRE_TIMES_SECONDS = "86400,604800,2592000";
    };

    serviceConfig = {
      Type             = "simple";
      WorkingDirectory = "/opt/send";
      ExecStart        = "${pkgs.nodejs}/bin/node /opt/send/server/index.js";
      EnvironmentFile  = config.age.secrets.sendSecret.path;
      DynamicUser      = true;

      NoNewPrivileges = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      PrivateTmp      = true;
      ReadWritePaths  = [ "/mnt/data/send" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/data                    0755 root      root      -"
    "d /mnt/data/paperless          0750 paperless paperless -"
    "d /mnt/data/paperless/media    0750 paperless paperless -"
    "d /mnt/data/paperless/consume  0750 paperless paperless -"
    "d /mnt/data/gitea              0750 gitea     gitea     -"
    "d /mnt/data/chiyogami          0750 chiyogami chiyogami -"
    "d /mnt/data/convertx           0750 convertx  convertx  -"
    "d /mnt/data/send               0750 send      send      -"
    "d /mnt/data/send/uploads       0750 send      send      -"
  ];

  users.users.admin = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/4M8fggqYWUdoG8DiWKLIhNWNmy7djUc9+FS/jI7LG leo@starborne"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    git
    htop
    curl
    wget
    jq
    age
    smartmontools
    lsof
    nodejs
  ];

  system.autoUpgrade = {
    enable      = true;
    flake       = "github:lakaki27/maelstrom#maelstrom";
    flags       = [ "--update-input" "nixpkgs" ];
    dates       = "04:00";
    allowReboot = false;
  };

  system.stateVersion = "25.11";
}
