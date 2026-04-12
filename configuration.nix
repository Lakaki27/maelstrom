{ config, pkgs, lib, ... }:


let
  composeDir = "/opt/maelstrom";
  composeRepo = "github:lakaki27/maelstrom";
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ──────────────────────────────────────────
  # Boot & hardware
  # ──────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.supportedFilesystems = [ "vfat" ];
  # Generate once: head -c 8 /dev/urandom | od -A n -t x8 | tr -d ' \n'
  networking.hostId = "4b3143a6";

  # ──────────────────────────────────────────
  # Networking
  # ──────────────────────────────────────────
  networking.hostName = "maelstrom";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80    # Traefik HTTP → HTTPS redirect
      443   # Traefik HTTPS
      8080  # Traefik dashboard
      51820 # WireGuard
    ];
    allowedUDPPorts = [ 51820 ];
  };

  # ──────────────────────────────────────────
  # ZFS
  # ──────────────────────────────────────────
  services.zfs = {
    autoScrub.enable = true;
    autoScrub.interval = "weekly";
    trim.enable = true;
  };

  fileSystems."/mnt/nas" = {
    device = "data/nas";
    fsType = "zfs";
    options = [ "zfsutil" "X-mount.mkdir" ];
    neededForBoot = false;
  };

  # ──────────────────────────────────────────
  # PostgreSQL (native)
  # ──────────────────────────────────────────
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    # All services connect via Unix socket with peer auth — no passwords needed
    ensureDatabases = [
      "paperless" "vaultwarden" "gitea"      # Seafile needs three separate databases
      "ccnet-db" "seafile-db" "seahub-db"
    ];
    ensureUsers = [
      { name = "paperless";   ensureDBOwnership = true; }
      { name = "vaultwarden"; ensureDBOwnership = true; }
      { name = "gitea";       ensureDBOwnership = true; }
      # Seafile uses one user across all three of its databases
      { name = "seafile"; ensureDBOwnership = false; }
    ];
    # Seafile needs explicit grants across its three DBs — done via initialScript
    initialScript = pkgs.writeText "seafile-pg-init" ''
      GRANT ALL PRIVILEGES ON DATABASE "ccnet-db"   TO seafile;
      GRANT ALL PRIVILEGES ON DATABASE "seafile-db" TO seafile;
      GRANT ALL PRIVILEGES ON DATABASE "seahub-db"  TO seafile;
    '';
    settings.listen_addresses = "localhost";
  };

  # ──────────────────────────────────────────
  # Redis (native)
  # ──────────────────────────────────────────
  services.redis.servers.maelstrom = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  # ──────────────────────────────────────────
  # Paperless-ngx (native)
  # ──────────────────────────────────────────
  services.paperless = {
    enable = true;
    dataDir = "/var/lib/paperless";
    mediaDir = "/var/lib/paperless/media";
    consumptionDir = "/mnt/nas/paperless/consume";
    # File containing the admin password (plain text, mode 400, owned by root)
    passwordFile = "/etc/secrets/paperless-admin-password";
    settings = {
      PAPERLESS_URL = "https://paperless.home";
      PAPERLESS_TIME_ZONE = "Europe/Paris";
      PAPERLESS_ADMIN_USER = "admin";
      # Unix socket connection to postgres — peer auth, no password
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_DBNAME = "paperless";
      PAPERLESS_DBUSER = "paperless";
      PAPERLESS_REDIS = "redis://127.0.0.1:6379";
    };
  };

  # ──────────────────────────────────────────
  # Vaultwarden (native)
  # Signups allowed — it's your password manager
  # ──────────────────────────────────────────
  services.vaultwarden = {
    enable = true;
    # Secrets (ADMIN_TOKEN, SMTP_PASSWORD, etc.) live here, outside the Nix store
    environmentFile = "/etc/secrets/vaultwarden.env";
    config = {
      DOMAIN = "https://vaultwarden.home";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
      # Unix socket peer auth
      DATABASE_URL = "postgresql://vaultwarden@localhost/vaultwarden?host=/run/postgresql";
      SMTP_PORT = 587;
      SMTP_SECURITY = "starttls";
      # SMTP_HOST, SMTP_FROM, SMTP_USERNAME, SMTP_PASSWORD → set in environmentFile
    };
  };

  # ──────────────────────────────────────────
  # Gitea (native)
  # ──────────────────────────────────────────
  services.gitea = {
    enable = true;
    stateDir = "/var/lib/gitea";
    database = {
      type = "postgres";
      socket = "/run/postgresql";
      name = "gitea";
      user = "gitea";
      createDatabase = false; # handled by ensureDatabases above
    };
    settings = {
      server = {
        DOMAIN = "gitea.home";
        ROOT_URL = "https://gitea.home";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3001;
      };
      service.DISABLE_REGISTRATION = true;
      mailer = {
        ENABLED = true;
        PROTOCOL = "smtp+starttls";
        SMTP_PORT = 587;
        # SMTP_ADDR, FROM, USER, PASSWD → set in secretFile
      };
    };
    # Format: GITEA__section__KEY=value, e.g. GITEA__mailer__SMTP_ADDR=smtp.example.com
    # secretFile = "/etc/secrets/gitea.env";
  };

  # ──────────────────────────────────────────
  # Gatus (native — added in nixpkgs 24.11)
  # ──────────────────────────────────────────
  services.gatus = {
    enable = true;
    settings = {
      web.port = 8090;
      storage.type = "memory";
      metrics = true;
      endpoints = [
        { name = "Traefik";     url = "https://traefik.home";     interval = "1m";  conditions = [ "[STATUS] < 400" ]; }
        { name = "Paperless";   url = "https://paperless.home";   interval = "2m";  conditions = [ "[STATUS] == 200" ]; }
        { name = "Vaultwarden"; url = "https://vaultwarden.home"; interval = "2m";  conditions = [ "[STATUS] == 200" ]; }
        { name = "Gitea";       url = "https://gitea.home";       interval = "2m";  conditions = [ "[STATUS] == 200" ]; }
        { name = "Chiyogami";   url = "https://chiyogami.home";   interval = "2m";  conditions = [ "[STATUS] == 200" ]; }
        { name = "ConvertX";    url = "https://convertx.home";    interval = "5m";  conditions = [ "[STATUS] < 400" ]; }
        { name = "Send";        url = "https://send.home";        interval = "2m";  conditions = [ "[STATUS] == 200" ]; }
        { name = "Deluge";      url = "https://deluge.home";      interval = "5m";  conditions = [ "[STATUS] < 400" ]; }
        { name = "Seafile";     url = "https://seafile.home";     interval = "2m";  conditions = [ "[STATUS] == 200" ]; }
        { name = "Homepage";    url = "https://home.home";        interval = "5m";  conditions = [ "[STATUS] == 200" ]; }
      ];
    };
  };

  # ──────────────────────────────────────────
  # Homepage dashboard (native)
  # App launcher — one card per service, with status from Gatus
  # Edit settings below to customise icons, groups, descriptions
  # ──────────────────────────────────────────
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    settings = {
      title = "maelstrom";
      theme = "dark";
      color = "slate";
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
        { Traefik     = { href = "https://traefik.home";     description = "Reverse proxy";         icon = "traefik.png"; }; }
        { Gatus       = { href = "https://gatus.home";       description = "Uptime monitoring";     icon = "gatus.png"; }; }
        { Deluge      = { href = "https://deluge.home";      description = "Torrent client";        icon = "deluge.png"; }; }
      ]; }
      { "Files & Docs" = [
        { Seafile     = { href = "https://seafile.home";     description = "File storage";          icon = "seafile.png"; }; }
        { Paperless   = { href = "https://paperless.home";   description = "Document manager";      icon = "paperless-ngx.png"; }; }
        { Send        = { href = "https://send.home";        description = "Encrypted file sharing"; icon = "send.png"; }; }
      ]; }
      { "Dev" = [
        { Gitea       = { href = "https://gitea.home";       description = "Git forge";             icon = "gitea.png"; }; }
        { Chiyogami   = { href = "https://chiyogami.home";   description = "Pastebin";              icon = "pastebin.png"; }; }
      ]; }
      { "Tools" = [
        { Vaultwarden = { href = "https://vaultwarden.home"; description = "Password manager";      icon = "vaultwarden.png"; }; }
        { ConvertX    = { href = "https://convertx.home";    description = "File converter";        icon = "convertx.png"; }; }
      ]; }
    ];
  };


  # NOTE: no VPN kill-switch in the NixOS module.
  # If you want one, either use a network namespace (advanced) or
  # move Deluge back to Docker with gluetun.
  # ──────────────────────────────────────────
  services.deluge = {
    enable = true;
    web.enable = true;
    web.port = 8112;
    dataDir = "/mnt/nas/downloads";
    declarative = true;
    # format: "username:password:level" e.g. "localclient:yourpassword:10"
    authFile = "/etc/secrets/deluge-auth";
    config = {
      download_location = "/mnt/nas/downloads";
      max_active_downloading = 3;
      max_active_seeding = 5;
    };
  };

  # ──────────────────────────────────────────
  # Docker — only for services without NixOS modules:
  # Traefik, Chiyogami, ConvertX, Send, Seafile
  # ──────────────────────────────────────────
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    daemon.settings.log-driver = "journald";
  };

  # ──────────────────────────────────────────
  # Users
  # ──────────────────────────────────────────
  users.users.maelstrom = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/4M8fggqYWUdoG8DiWKLIhNWNmy7djUc9+FS/jI7LG leo@starborne"
    ];
  };

  # ──────────────────────────────────────────
  # System packages
  # ──────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    docker-compose
    git
    htop
    curl
    wget
    jq
    zfs
    smartmontools
    lsof
  ];

  # ──────────────────────────────────────────
  # SSH
  # ──────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ──────────────────────────────────────────
  # Auto-upgrade (NixOS system)
  # ──────────────────────────────────────────
  system.autoUpgrade = {
    enable = true;
    flake = "${composeRepo}#maelstrom";
    flags = [ "--update-input" "nixpkgs" ];
    dates = "04:00";
    allowReboot = false;
  };

  # ──────────────────────────────────────────
  # Compose pull timer (Docker-only services)
  # ──────────────────────────────────────────
  systemd.services.compose-pull = {
    description = "Pull and restart Docker-only services when compose.yaml changes";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = composeDir;
      EnvironmentFile = "${composeDir}/.env";
      ExecStart = pkgs.writeShellScript "compose-pull" ''
        set -euo pipefail
        HASH_FILE="/var/lib/compose-pull/last-hash"
        REPO="lakaki27/maelstrom"
        mkdir -p "$(dirname "$HASH_FILE")"
        CURRENT=$(${pkgs.curl}/bin/curl -sf \
          "https://api.github.com/repos/$REPO/commits?path=compose.yaml&per_page=1" \
          | ${pkgs.jq}/bin/jq -r '.[0].sha')
        LAST=$(cat "$HASH_FILE" 2>/dev/null || echo "none")
        if [ "$CURRENT" = "$LAST" ]; then
          echo "compose.yaml unchanged ($CURRENT), skipping."
          exit 0
        fi
        echo "Change detected ($LAST → $CURRENT). Pulling and restarting..."
        ${pkgs.git}/bin/git -C ${composeDir} pull --ff-only
        ${pkgs.docker-compose}/bin/docker-compose pull
        ${pkgs.docker-compose}/bin/docker-compose up -d --remove-orphans
        echo "$CURRENT" > "$HASH_FILE"
      '';
      Restart = "no";
    };
  };

  systemd.timers.compose-pull = {
    description = "Check for compose.yaml updates every 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/compose-pull 0755 root root -"
    "d /etc/secrets 0700 root root -"
    "d ${composeDir} 0750 maelstrom docker -"
  ];

  # ──────────────────────────────────────────
  # WireGuard
  # ──────────────────────────────────────────
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private.key";
    peers = [
      # { publicKey = "..."; allowedIPs = [ "10.100.0.2/32" ]; }
    ];
    postSetup = ''
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
    '';
    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
    '';
  };
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # ──────────────────────────────────────────
  # Locale & time
  # ──────────────────────────────────────────
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
