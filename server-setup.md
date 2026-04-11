# maelstrom — server setup guide

## 1. NixOS install

Standard NixOS install on the N100. After partitioning, clone your repo to `/opt/maelstrom` and symlink the flake:

```bash
git clone https://github.com/youruser/maelstrom /opt/maelstrom
nixos-install --flake /opt/maelstrom#maelstrom
```

---

## 2. Generate a ZFS host ID

This must be unique per machine and must match `networking.hostId` in `configuration.nix`.

```bash
head -c 8 /dev/urandom | od -A n -t x8 | tr -d ' \n'
# e.g. → deadbeef12345678  (use only the first 8 chars)
```

Update `configuration.nix` with that value before first build.

---

## 3. Create the ZFS pool (once, when 4TB drive arrives)

```bash
# Find your disk ID
ls /dev/disk/by-id/

# Create the pool (ashift=12 for 4K sector drives — correct for most modern HDDs)
zpool create -f -o ashift=12 data /dev/disk/by-id/YOUR-DISK-ID

# Create datasets
zfs create data/nas
zfs create data/nas/music
zfs create data/nas/downloads

# Optional: enable compression (transparent, good ratio on media)
zfs set compression=lz4 data/nas
```

Until the drive arrives, the `/mnt/nas` mount in `configuration.nix` will simply be absent — this is fine since `neededForBoot = false`.

---

## 4. Generate TLS certificates (self-signed, local .home domains)

```bash
mkdir -p /opt/maelstrom/traefik/certs
cd /opt/maelstrom/traefik/certs

openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
  -keyout local.key -out local.crt \
  -subj "/CN=*.home" \
  -addext "subjectAltName=DNS:*.home,DNS:home"
```

Then **import `local.crt` into your browser / OS trust store** on every device that will access the server, so you don't get TLS warnings.

---

## 5. Add `.home` DNS entries

On your router (or a Pi-hole / AdGuard Home if you run one), add DNS A records pointing every `*.home` subdomain to your server's LAN IP:

```
traefik.home    → 192.168.1.X
paperless.home  → 192.168.1.X
vaultwarden.home → 192.168.1.X
# ... etc for all services
```

Or use a wildcard `*.home → 192.168.1.X` if your router supports it.

---

## 6. Configure secrets

```bash
cp /opt/maelstrom/.env.example /opt/maelstrom/.env
# Edit .env and fill every value
nano /opt/maelstrom/.env
```

---

## 7. WireGuard keys

```bash
# Generate server keypair
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
chmod 600 /etc/wireguard/private.key

# For each client device, generate a keypair on that device:
# wg genkey | tee client.key | wg pubkey > client.pub
# Then add the client public key to the `peers` list in configuration.nix
```

---

## 8. First `docker compose up`

```bash
cd /opt/maelstrom
docker compose pull
docker compose up -d
```

Check logs for any issues:
```bash
docker compose logs -f traefik
docker compose logs -f postgres
```

---

## 9. Vaultwarden: migrate from SQLite to PostgreSQL

If you previously ran Vaultwarden with SQLite, use the official migration tool before first boot with the new config:

```bash
# https://github.com/ambitionworks/vaultwarden-migrate
docker run --rm \
  -v ./vaultwarden/data:/data \
  -e DB_URL="postgresql://postgres:YOUR_PASSWORD@postgres:5432/vaultwarden" \
  ghcr.io/ambitionworks/vaultwarden-migrate
```

If this is a fresh install, no migration is needed.

---

## 10. MMDL image

The `mmdl` image tag in `compose.yaml` is a placeholder — verify the correct image at:
https://github.com/nicholasgasior/mmdl (or wherever you sourced it) and update accordingly.

---

## Future: public domain + Let's Encrypt

When you get a domain:

1. Add to Traefik command args:
   ```yaml
   - --certificatesresolvers.le.acme.tlschallenge=true
   - --certificatesresolvers.le.acme.email=you@example.com
   - --certificatesresolvers.le.acme.storage=/certs/acme.json
   ```
2. On each router label, add: `traefik.http.routers.X.tls.certresolver=le`
3. Remove the static `tls.yml` file reference
4. Expose port 443 externally on your router (port-forward)
