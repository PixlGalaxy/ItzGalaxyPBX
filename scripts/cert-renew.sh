#!/usr/bin/env bash
set -euo pipefail

PBX_DOMAIN="${PBX_DOMAIN:-pbx.example.com}"
ASTERISK_KEYS_DIR="${ASTERISK_KEYS_DIR:-/etc/asterisk/keys}"
LE_LIVE_DIR="/etc/letsencrypt/live/${PBX_DOMAIN}"

echo "[cert-renew] Renewing TLS certificates for ${PBX_DOMAIN}…"

if command -v certbot >/dev/null 2>&1; then
  certbot renew --deploy-hook "systemctl reload apache2 || systemctl reload httpd || true" || true
else
  echo "[cert-renew][WARN] certbot not found; skipping automatic renew."
fi

if [ -d "${LE_LIVE_DIR}" ]; then
  mkdir -p "${ASTERISK_KEYS_DIR}"
  cp -f "${LE_LIVE_DIR}/fullchain.pem" "${ASTERISK_KEYS_DIR}/asterisk.pem" || true
  cp -f "${LE_LIVE_DIR}/privkey.pem"   "${ASTERISK_KEYS_DIR}/asterisk.key" || true
  chmod 600 "${ASTERISK_KEYS_DIR}/asterisk.key" || true
  if command -v asterisk >/dev/null 2>&1; then
    asterisk -rx "core reload" || true
  fi
  if command -v fwconsole >/dev/null 2>&1; then
    fwconsole certificates updateall || true
    fwconsole reload || true
  fi
  echo "[cert-renew] Synced certs into Asterisk and reloaded."
else
  echo "[cert-renew][INFO] Let's Encrypt path not found for ${PBX_DOMAIN}; skipping."
fi
