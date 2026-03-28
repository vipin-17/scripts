#!/bin/bash
# =============================================================================
#  setup_fail2ban.sh — Install & configure Fail2ban with hardened SSH rules
#  Tested on: Debian 10 / 11 / 12
#  Run as:    sudo bash setup_fail2ban.sh
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Please run this script as root: sudo bash $0"
fi

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}   Fail2ban Setup — Debian VPS Hardening Script            ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# =============================================================================
# STEP 1 — Detect SSH port
# =============================================================================
info "Detecting SSH port..."

SSH_PORT=$(ss -tlnp | grep -oP '(?<=:)\d+(?=\s)' | grep -E '^22$|^[0-9]{4,5}$' | head -1 || true)

if [[ -z "$SSH_PORT" ]]; then
  SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1 || echo "22")
fi

SSH_PORT=${SSH_PORT:-22}
success "SSH port detected: $SSH_PORT"

# =============================================================================
# STEP 2 — Auto-detect available firewall and set banaction
# =============================================================================
info "Detecting available firewall..."

BANACTION_SINGLE=""
BANACTION_ALL=""
FIREWALL_NAME=""

# ── Test iptables ──────────────────────────────────────────────────────────────
if command -v iptables &>/dev/null; then
  # iptables exists — test if we actually have permission to use it
  if iptables -L -n &>/dev/null 2>&1; then
    FIREWALL_NAME="iptables"
    BANACTION_SINGLE="iptables-multiport"
    BANACTION_ALL="iptables-allports"
  fi
fi

# ── Test nftables (if iptables not usable) ────────────────────────────────────
if [[ -z "$FIREWALL_NAME" ]]; then
  if command -v nft &>/dev/null; then
    if nft list ruleset &>/dev/null 2>&1; then
      FIREWALL_NAME="nftables"
      BANACTION_SINGLE="nftables-multiport"
      BANACTION_ALL="nftables-allports"
    fi
  fi
fi

# ── Try installing iptables if nothing found ──────────────────────────────────
if [[ -z "$FIREWALL_NAME" ]]; then
  warn "No working firewall detected. Attempting to install iptables..."
  apt-get update -qq
  apt-get install -y iptables

  if iptables -L -n &>/dev/null 2>&1; then
    FIREWALL_NAME="iptables"
    BANACTION_SINGLE="iptables-multiport"
    BANACTION_ALL="iptables-allports"
    success "iptables installed and working."
  fi
fi

# ── Try installing nftables if iptables install also failed ───────────────────
if [[ -z "$FIREWALL_NAME" ]]; then
  warn "iptables not usable (likely a restricted container). Trying nftables..."
  apt-get install -y nftables
  systemctl enable nftables --quiet
  systemctl start nftables

  if nft list ruleset &>/dev/null 2>&1; then
    FIREWALL_NAME="nftables"
    BANACTION_SINGLE="nftables-multiport"
    BANACTION_ALL="nftables-allports"
    success "nftables installed and working."
  fi
fi

# ── Fallback — route action (works on restricted containers, no fw needed) ────
if [[ -z "$FIREWALL_NAME" ]]; then
  warn "Neither iptables nor nftables available on this system."
  warn "Falling back to 'route' banaction — IPs will be null-routed at kernel level."
  warn "This works on most restricted containers without firewall access."
  FIREWALL_NAME="route (no firewall available)"
  BANACTION_SINGLE="route"
  BANACTION_ALL="route"
fi

success "Firewall: $FIREWALL_NAME"
success "Ban action (single jail): $BANACTION_SINGLE"
success "Ban action (recidive/all ports): $BANACTION_ALL"

# =============================================================================
# STEP 3 — Ensure rsyslog is installed so /var/log/auth.log exists
# =============================================================================
info "Checking for rsyslog (required for /var/log/auth.log)..."

if ! dpkg -l | grep -q "^ii.*rsyslog"; then
  info "rsyslog not found — installing..."
  apt-get update -qq
  apt-get install -y rsyslog
  success "rsyslog installed."
else
  success "rsyslog already installed."
fi

systemctl enable rsyslog --quiet
systemctl restart rsyslog
sleep 2

if [[ -f /var/log/auth.log ]]; then
  success "/var/log/auth.log is present."
else
  touch /var/log/auth.log
  warn "/var/log/auth.log created manually — rsyslog will populate it going forward."
fi

# =============================================================================
# STEP 4 — Install Fail2ban if not present
# =============================================================================
info "Checking if fail2ban is installed..."

if dpkg -l | grep -q "^ii.*fail2ban"; then
  success "fail2ban is already installed — skipping install."
else
  info "fail2ban not found. Installing..."
  apt-get update -qq
  apt-get install -y fail2ban
  success "fail2ban installed successfully."
fi

# =============================================================================
# STEP 5 — Backup existing jail.local if present
# =============================================================================
JAIL_LOCAL="/etc/fail2ban/jail.local"

if [[ -f "$JAIL_LOCAL" ]]; then
  BACKUP_PATH="${JAIL_LOCAL}.bak.$(date +%Y%m%d_%H%M%S)"
  info "Existing jail.local found — backing up to $BACKUP_PATH"
  cp "$JAIL_LOCAL" "$BACKUP_PATH"
  success "Backup saved: $BACKUP_PATH"
fi

# =============================================================================
# STEP 6 — Write jail.local using detected firewall banaction
# =============================================================================
info "Writing hardened jail.local config..."

cat > "$JAIL_LOCAL" <<EOF
# =============================================================================
#  /etc/fail2ban/jail.local
#  Generated by setup_fail2ban.sh on $(date)
#  Firewall detected: ${FIREWALL_NAME}
#  DO NOT edit jail.conf — this file takes precedence and survives updates.
# =============================================================================

[DEFAULT]

# ── Whitelist ─────────────────────────────────────────────────────────────────
# Uncomment and add your own IPs to avoid getting locked out:
# ignoreip = 127.0.0.1/8 ::1 YOUR.IP.HERE
ignoreip = 127.0.0.1/8 ::1

# ── Timing ────────────────────────────────────────────────────────────────────
bantime  = 24h
findtime = 5m
maxretry = 3

# ── IPv6 ──────────────────────────────────────────────────────────────────────
allowipv6 = auto

# ── Backend ───────────────────────────────────────────────────────────────────
backend = auto

# ── Action (auto-detected: ${FIREWALL_NAME}) ──────────────────────────────────
banaction = ${BANACTION_SINGLE}


# =============================================================================
#  SSH JAIL — Primary protection
# =============================================================================
[sshd]
enabled   = true
port      = ${SSH_PORT}
filter    = sshd
logpath   = /var/log/auth.log
maxretry  = 3
findtime  = 5m
bantime   = 48h
banaction = ${BANACTION_SINGLE}


# =============================================================================
#  RECIDIVE JAIL — Bans repeat offenders across ALL ports for 4 weeks
# =============================================================================
[recidive]
enabled   = true
logpath   = /var/log/fail2ban.log
banaction = ${BANACTION_ALL}
maxretry  = 5
findtime  = 1d
bantime   = 4w
EOF

success "jail.local written to $JAIL_LOCAL"

# =============================================================================
# STEP 7 — Validate config before starting
# =============================================================================
info "Validating fail2ban config..."

if fail2ban-client -t 2>&1 | grep -q "successful"; then
  success "Config validation passed."
else
  error "Config validation failed. Run: fail2ban-client -t"
fi

# =============================================================================
# STEP 8 — Enable & restart Fail2ban
# =============================================================================
info "Enabling and restarting fail2ban service..."

systemctl enable fail2ban --quiet
systemctl restart fail2ban

sleep 3

# =============================================================================
# STEP 9 — Verify everything is running
# =============================================================================
info "Verifying fail2ban status..."

if systemctl is-active --quiet fail2ban; then
  success "fail2ban is running."
else
  echo ""
  echo -e "${RED}fail2ban failed to start. Full error below:${NC}"
  echo ""
  journalctl -u fail2ban --since "1 minute ago" --no-pager
  echo ""
  error "Fix the errors above then run: sudo systemctl restart fail2ban"
fi

echo ""
info "Active jails:"
fail2ban-client status

echo ""
info "SSH jail detail:"
fail2ban-client status sshd || warn "sshd jail not ready yet — try: sudo fail2ban-client status sshd"

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}   Setup complete!                                          ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  ${CYAN}SSH Port      :${NC} $SSH_PORT"
echo -e "  ${CYAN}Firewall      :${NC} $FIREWALL_NAME"
echo -e "  ${CYAN}Ban action    :${NC} $BANACTION_SINGLE"
echo -e "  ${CYAN}Config file   :${NC} $JAIL_LOCAL"
echo -e "  ${CYAN}Auth log      :${NC} /var/log/auth.log"
echo -e "  ${CYAN}Fail2ban log  :${NC} /var/log/fail2ban.log"
echo ""
echo -e "  ${YELLOW}Tip:${NC} Add your own IP to ignoreip in $JAIL_LOCAL to avoid lockouts"
echo ""
echo -e "  ${YELLOW}Useful commands:${NC}"
echo "    sudo fail2ban-client status                    # All active jails"
echo "    sudo fail2ban-client status sshd               # SSH jail + banned IPs"
echo "    sudo tail -f /var/log/fail2ban.log             # Live ban activity"
echo "    sudo fail2ban-client set sshd unbanip <IP>     # Unban an IP"
echo ""
