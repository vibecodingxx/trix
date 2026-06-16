#!/usr/bin/env bash
# BBR basic tweak
# Date: 2025-11-29
# BY : XCODEX

set -o pipefail

green='\033[0;32m'
red='\033[1;31m'
yellow='\033[1;33m'
bold_green='\033[32;1m'
reset='\033[0m'

log() {
  printf '%b%s%b\n' "$green" "$*" "$reset"
}

warn() {
  printf '%b%s%b\n' "$yellow" "$*" "$reset"
}

die() {
  printf '%b%s%b\n' "$red" "$*" "$reset" >&2
  exit 1
}

ensure_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "Please run this script as root."
  fi
}

ensure_file() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  touch "$file"
}

ensure_final_newline() {
  local file="$1"

  [ -s "$file" ] || return 0
  if [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$file"
  fi
}

ensure_line() {
  local file="$1"
  local line="$2"

  ensure_file "$file"
  if ! grep -Fxq -- "$line" "$file"; then
    ensure_final_newline "$file"
    printf '%s\n' "$line" >> "$file"
  fi
}

upsert_sysctl_conf() {
  local key="$1"
  local value="$2"
  local file="/etc/sysctl.conf"
  local tmp

  ensure_file "$file"
  tmp="$(mktemp)"

  awk -v key="$key" -v value="$value" '
    {
      raw = $0
      line = $0
      sub(/^[[:space:]]*#?[[:space:]]*/, "", line)
      split(line, parts, "=")
      current_key = parts[1]
      sub(/[[:space:]]+$/, "", current_key)

      if (current_key == key) {
        if (!done) {
          print key " = " value
          done = 1
        }
        next
      }

      print raw
    }
    END {
      if (!done) {
        print key " = " value
      }
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

apply_sysctl() {
  local key="$1"
  local value="$2"
  local required="${3:-0}"

  if sysctl -w "$key=$value" >/dev/null 2>&1; then
    upsert_sysctl_conf "$key" "$value"
    return 0
  fi

  if [ "$required" = "1" ]; then
    die "Failed to apply sysctl: $key = $value"
  fi

  warn "Skipped unsupported sysctl: $key"
  return 0
}

bbr_available() {
  sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr
}

bbr_enabled() {
  [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ]
}

install_bbr() {
  printf '%b================================%b\n' "$bold_green" "$reset"
  printf '%bInstall TCP BBR...%b\n' "$bold_green" "$reset"

  modprobe tcp_bbr 2>/dev/null || true
  ensure_line "/etc/modules-load.d/modules.conf" "tcp_bbr"

  if ! bbr_available; then
    die "TCP BBR is not available on this kernel."
  fi

  apply_sysctl "net.core.default_qdisc" "fq" 1
  apply_sysctl "net.ipv4.tcp_congestion_control" "bbr" 1

  if bbr_enabled; then
    log "Success install TCP BBR."
  else
    die "Failed to enable TCP BBR."
  fi

  printf '%b================================%b\n' "$bold_green" "$reset"
}

optimize_parameters() {
  printf '%b================================%b\n' "$bold_green" "$reset"
  printf '%bOptimize Parameters...%b\n' "$bold_green" "$reset"

  ensure_line "/etc/security/limits.conf" "* soft nofile 51200"
  ensure_line "/etc/security/limits.conf" "* hard nofile 51200"
  ensure_line "/etc/security/limits.conf" "root soft nofile 51200"
  ensure_line "/etc/security/limits.conf" "root hard nofile 51200"

  apply_sysctl "fs.file-max" "1000000"
  apply_sysctl "net.core.rmem_max" "67108864"
  apply_sysctl "net.core.wmem_max" "67108864"
  apply_sysctl "net.core.netdev_max_backlog" "250000"
  apply_sysctl "net.core.somaxconn" "4096"
  apply_sysctl "net.ipv4.tcp_syncookies" "1"
  apply_sysctl "net.ipv4.tcp_tw_reuse" "1"
  apply_sysctl "net.ipv4.tcp_fin_timeout" "30"
  apply_sysctl "net.ipv4.tcp_keepalive_time" "1200"
  apply_sysctl "net.ipv4.ip_local_port_range" "10000 65000"
  apply_sysctl "net.ipv4.tcp_max_syn_backlog" "8192"
  apply_sysctl "net.ipv4.tcp_max_tw_buckets" "5000"
  apply_sysctl "net.ipv4.tcp_fastopen" "3"
  apply_sysctl "net.ipv4.tcp_mem" "25600 51200 102400"
  apply_sysctl "net.ipv4.tcp_rmem" "4096 87380 67108864"
  apply_sysctl "net.ipv4.tcp_wmem" "4096 65536 67108864"
  apply_sysctl "net.ipv4.tcp_mtu_probing" "1"

  log "Successfully optimized parameters."
  printf '%b================================%b\n' "$bold_green" "$reset"
}

main() {
  ensure_root
  install_bbr
  optimize_parameters
  rm -f /root/bbr.sh
}

main "$@"
