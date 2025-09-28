#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] ItzGalaxyPBX starting…"

# Small delay so /dev/ttyUSB* exist inside the container
SLEEP_DEVICES="${SLEEP_DEVICES:-2}"
sleep "${SLEEP_DEVICES}"

# --- Helper: detect Linux package manager inside this image -------------
detect_pm() {
  if command -v apk >/dev/null 2>&1;  then echo "apk";  return; fi
  if command -v apt-get >/dev/null 2>&1; then echo "apt";  return; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf";  return; fi
  if command -v yum >/dev/null 2>&1; then echo "yum";  return; fi
  echo "none"
}

install_build_deps_if_needed() {
  local pm; pm="$(detect_pm)"
  echo "[entrypoint] Package manager: ${pm}"
  case "$pm" in
    apk)
      echo "[entrypoint] Installing build deps via apk…"
      apk update || true
      apk add --no-cache git build-base automake autoconf libtool pkgconf
      ;;
    apt)
      echo "[entrypoint] Installing build deps via apt…"
      apt-get update -y || true
      DEBIAN_FRONTEND=noninteractive apt-get install -y git build-essential automake autoconf libtool pkg-config
      ;;
    dnf)
      echo "[entrypoint] Installing build deps via dnf…"
      dnf -y groupinstall "Development Tools" || true
      dnf -y install git automake autoconf libtool pkgconfig
      ;;
    yum)
      echo "[entrypoint] Installing build deps via yum…"
      yum -y groupinstall "Development Tools" || true
      yum -y install git automake autoconf libtool pkgconfig
      ;;
    *)
      echo "[entrypoint][WARN] No known package manager; skipping build deps."
      ;;
  esac
}
# -----------------------------------------------------------------------

build_chan_dongle_if_missing() {
  if ls /usr/lib*/asterisk/modules/chan_dongle.so >/dev/null 2>&1 ; then
    echo "[entrypoint] chan_dongle already present. Skipping build."
    return
  fi
  echo "[entrypoint] chan_dongle not found. Building from source…"
  install_build_deps_if_needed

  mkdir -p /usr/src
  cd /usr/src
  if [ ! -d asterisk-chan-dongle ]; then
    git clone https://github.com/bg111/asterisk-chan-dongle.git
  fi
  cd asterisk-chan-dongle

  if [ ! -f ./configure ]; then
    echo "[entrypoint] Generating configure via autoreconf…"
    autoreconf -i
  fi

  echo "[entrypoint] ./configure && make && make install"
  ./configure
  make
  make install

  if ! ls /usr/lib*/asterisk/modules/chan_dongle.so >/dev/null 2>&1 ; then
    echo "[entrypoint][ERROR] chan_dongle.so not installed as expected."
    exit 1
  fi
  echo "[entrypoint] chan_dongle build complete."
}

start_base_services() {
  echo "[entrypoint] Starting base services (db/web/logging) if available…"
  if command -v service >/dev/null 2>&1; then
    service mariadb start || service mysql start || true
    service apache2 start || service httpd start || true
    service rsyslog start || true
  fi

  if command -v fwconsole >/dev/null 2>&1; then
    fwconsole chown || true
    fwconsole ma refreshsignatures || true
    # Bootstrap admin if requested
    if [ -n "${FREEPBX_ADMIN_USER:-}" ] && [ -n "${FREEPBX_ADMIN_PASS:-}" ]; then
      echo "[entrypoint] Ensuring FreePBX admin user exists…"
      fwconsole userman show ${FREEPBX_ADMIN_USER} >/dev/null 2>&1 || \
      fwconsole userman add ${FREEPBX_ADMIN_USER} --password="${FREEPBX_ADMIN_PASS}" --group=All Users || true
    fi
  fi
}

start_asterisk_and_tail() {
  echo "[entrypoint] Launching Asterisk…"
  if ! command -v asterisk >/dev/null 2>&1; then
    echo "[entrypoint][ERROR] asterisk not found in PATH."
    exit 1
  fi

  asterisk -f -U asterisk -G asterisk -C /etc/asterisk/asterisk.conf &
  AST_PID=$!

  sleep 3
  asterisk -rx "module load chan_dongle.so" || true
  asterisk -rx "dongle show devices" || true

  if command -v fwconsole >/dev/null 2>&1; then
    fwconsole start || true
  fi

  echo "[entrypoint] Asterisk running (pid=${AST_PID}). Tailing /var/log/asterisk/full…"
  tail -F /var/log/asterisk/full &
  wait "${AST_PID}"
}

main() {
  start_base_services

  echo "[entrypoint] Rendering configs from environment…"
  /scripts/setup-env.sh

  echo "[entrypoint] Detecting dongle and writing dongle.conf…"
  /scripts/init-dongle.sh

  echo "[entrypoint] Ensuring chan_dongle module is available…"
  build_chan_dongle_if_missing

  # If Asterisk already up (image behavior), just reload; else start it.
  if asterisk -rx "core show uptime" >/dev/null 2>&1; then
    echo "[entrypoint] Asterisk is already running. Reloading core and dongle…"
    asterisk -rx "core reload" || true
    asterisk -rx "module load chan_dongle.so" || true
    asterisk -rx "dongle show devices" || true
    tail -F /var/log/asterisk/full
  else
    start_asterisk_and_tail
  fi
}

main
