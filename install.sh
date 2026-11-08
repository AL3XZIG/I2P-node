#!/usr/bin/env bash
set -Eeuo pipefail

# I2P-node bootstrap installer for Debian 12/13 and Ubuntu 22.04/24.04/26.04.
# Installs official Java I2P, systemd service, and a local Nginx origin for an Eepsite.
# It does NOT expose Router Console or open firewall ports automatically.

readonly KEY_URL="https://i2p.net/i2p-archive-keyring.gpg"
readonly KEY_FINGERPRINT="7840E7610F28B904753549D767ECE5605BCF1346"
readonly REPO_URL="https://deb.i2p.net"
readonly UBUNTU_PPA="ppa:i2p-maintainers/i2p"
readonly KEYRING="/usr/share/keyrings/i2p-archive-keyring.gpg"
readonly REPO_FILE="/etc/apt/sources.list.d/i2p.list"
readonly SITE_ROOT="/var/www/i2p-site"
readonly NGINX_SITE="/etc/nginx/sites-available/i2p-site"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

trap 'rc=$?; warn "Installation stopped (exit code: $rc). See the message above."; exit "$rc"' ERR

[[ "${EUID}" -eq 0 ]] || die "Run as root: sudo bash install.sh"
[[ -r /etc/os-release ]] || die "Cannot identify operating system."

. /etc/os-release

case "${ID:-}" in
  debian)
    case "${VERSION_ID:-}" in
      12|13) DISTRO_FAMILY="debian" ;;
      *) die "Unsupported Debian version: ${VERSION_ID:-unknown}. Use Debian 12 or 13." ;;
    esac
    ;;
  ubuntu)
    case "${VERSION_ID:-}" in
      22.04|24.04|26.04) DISTRO_FAMILY="ubuntu" ;;
      *) die "Unsupported Ubuntu version: ${VERSION_ID:-unknown}. Use Ubuntu 22.04, 24.04, or 26.04 LTS." ;;
    esac
    ;;
  *)
    die "Unsupported distribution: ${ID:-unknown}. Supported: Debian 12/13 and Ubuntu 22.04/24.04/26.04."
    ;;
esac

command -v systemctl >/dev/null 2>&1 || die "systemd is required."
command -v apt-get >/dev/null 2>&1 || die "APT is required."

echo "I2P-node installer"
echo "OS: ${PRETTY_NAME:-${ID} ${VERSION_ID}}"
if [[ "$DISTRO_FAMILY" == "debian" ]]; then
  echo "I2P source: official deb.i2p.net repository"
else
  echo "I2P source: official Ubuntu PPA ($UBUNTU_PPA)"
fi
echo "Will install: official Java I2P, Nginx, and a local Eepsite web root."
echo "Will NOT: open public firewall ports, expose Router Console, or force Floodfill."
echo
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || { echo "Cancelled."; exit 0; }

export DEBIAN_FRONTEND=noninteractive

log "Installing prerequisites..."
apt-get update
if [[ "$DISTRO_FAMILY" == "ubuntu" ]]; then
  apt-get install -y --no-install-recommends ca-certificates curl gnupg nginx software-properties-common
else
  apt-get install -y --no-install-recommends ca-certificates curl gnupg nginx
fi

if [[ "$DISTRO_FAMILY" == "debian" ]]; then
  log "Downloading and verifying the official I2P repository key..."
  tmp_key="$(mktemp)"
  trap 'rm -f "${tmp_key:-}"' EXIT
  curl --fail --silent --show-error --location "$KEY_URL" -o "$tmp_key"

  actual_fingerprint="$(gpg --batch --show-keys --with-colons "$tmp_key" | awk -F: '$1 == "fpr" {print toupper($10); exit}')"
  [[ "$actual_fingerprint" == "$KEY_FINGERPRINT" ]] || die "I2P signing-key fingerprint mismatch. Expected $KEY_FINGERPRINT, got ${actual_fingerprint:-none}. Refusing to continue."

  install -o root -g root -m 0644 "$tmp_key" "$KEYRING"
  rm -f "$tmp_key"
  trap - EXIT

  log "Adding the official I2P APT repository..."
  printf 'deb [signed-by=%s] %s %s main\n' "$KEYRING" "$REPO_URL" "$VERSION_CODENAME" > "$REPO_FILE"

  log "Installing Java I2P and its keyring package..."
  apt-get update
  apt-get install -y i2p i2p-keyring
else
  log "Adding the official I2P Ubuntu PPA..."
  add-apt-repository --yes "$UBUNTU_PPA"
  apt-get update

  log "Installing Java I2P from the official Ubuntu PPA..."
  apt-get install -y i2p
fi

log "Enabling the I2P system service..."
if systemctl cat i2p.service >/dev/null 2>&1; then
  systemctl enable --now i2p.service
elif systemctl cat i2p >/dev/null 2>&1; then
  systemctl enable --now i2p
else
  warn "I2P systemd unit was not found. Run 'sudo dpkg-reconfigure i2p' and enable the system service, then start it."
fi

log "Preparing a private local website origin for an I2P Eepsite..."
install -d -o www-data -g www-data -m 0755 "$SITE_ROOT"
if [[ ! -e "$SITE_ROOT/index.html" ]]; then
  cat > "$SITE_ROOT/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>My I2P Eepsite</title>
</head>
<body>
  <h1>My I2P Eepsite</h1>
  <p>Your local website origin is running. Configure an I2P HTTP Server Tunnel
     to forward requests to <code>127.0.0.1:8080</code>.</p>
</body>
</html>
HTML
  chown www-data:www-data "$SITE_ROOT/index.html"
fi

cat > "$NGINX_SITE" <<NGINX
server {
    listen 127.0.0.1:8080;
    server_name _;
    root $SITE_ROOT;
    index index.html;

    access_log /var/log/nginx/i2p-site.access.log;
    error_log  /var/log/nginx/i2p-site.error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX

ln -sfn "$NGINX_SITE" /etc/nginx/sites-enabled/i2p-site
# Disable the package default vhost so Nginx does not expose a public port 80 page.
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

log "Checking local website response..."
curl --fail --silent http://127.0.0.1:8080/ >/dev/null || die "Nginx did not serve the local test page."

echo
log "Installation finished."
echo "I2P service:   systemctl status i2p"
echo "I2P logs:      journalctl -u i2p -f"
echo "Nginx status:  systemctl status nginx"
echo "Local website: http://127.0.0.1:8080/"
echo
echo "NEXT:"
echo "1. Open the I2P Router Console through an SSH tunnel: ssh -L 7657:127.0.0.1:7657 USER@SERVER_IP"
echo "2. In Hidden Services Manager, create an HTTP Server Tunnel to 127.0.0.1:8080."
echo "3. Keep Router Console (7657) bound to localhost; do not publish it."
echo "4. Open the I2P transport port shown in Router Console in the VPS provider firewall and host firewall."
echo "5. Floodfill is assigned by I2P automatically; this installer cannot force that role."
