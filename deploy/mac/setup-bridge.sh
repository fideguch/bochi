#!/bin/bash
# setup-bridge.sh — idempotent installer for the Mac Claude bridge.
# Pattern follows mobile-dev-bridge installers: dry-run by default,
# --apply to act, --uninstall, --status. plutil-lint before bootstrap.
set -euo pipefail

REPO="/Users/fumito_ideguchi/bochi"
RUNTIME="/Users/fumito_ideguchi/bochi-runtime"
AGENTS_DIR="/Users/fumito_ideguchi/Library/LaunchAgents"
PLIST_MAIN="com.fideguch.claude-bridge"
PLIST_HEALTH="com.fideguch.claude-bridge-health"
GUI_DOMAIN="gui/$(id -u)"

MODE="${1:---dry-run}"

say() { echo "[setup-bridge] $*"; }

install_agents() {
  local apply="$1"

  say "1) Runtime directory ($RUNTIME)"
  if [ "$apply" = "yes" ]; then
    mkdir -p "$RUNTIME"/{workspace,logs,bin} "$RUNTIME/.claude"
    for pair in \
      "deploy/mac-claude.md:$RUNTIME/CLAUDE.md:444" \
      "deploy/mac/templates/bridge-settings.json:$RUNTIME/.claude/settings.json:444" \
      "deploy/mac/bridge-guard.sh:$RUNTIME/bin/bridge-guard.sh:555" \
      "deploy/mac/bridge-guard.py:$RUNTIME/bin/bridge-guard.py:555" \
      "deploy/mac/bridge-start.sh:$RUNTIME/bin/bridge-start.sh:555" \
      "deploy/mac/bridge-health.sh:$RUNTIME/bin/bridge-health.sh:555" \
      "deploy/mac/notify-owner.sh:$RUNTIME/bin/notify-owner.sh:555" \
      "deploy/mac/bin/pc-status:$RUNTIME/bin/pc-status:555" \
      "deploy/mac/bin/repo-status:$RUNTIME/bin/repo-status:555"; do
      src="$REPO/${pair%%:*}"; rest="${pair#*:}"; dst="${rest%%:*}"; mode="${rest##*:}"
      tmp="$(dirname "$dst")/.$(basename "$dst").new.$$"
      cp "$src" "$tmp"; chmod "$mode" "$tmp"; mv -f "$tmp" "$dst"
      say "   installed $dst ($mode)"
    done
  else
    say "   would install CLAUDE.md, settings.json, bin/* into $RUNTIME"
  fi

  say "2) LaunchAgents"
  for name in "$PLIST_MAIN" "$PLIST_HEALTH"; do
    local src="$REPO/deploy/mac/templates/$name.plist" dst="$AGENTS_DIR/$name.plist"
    plutil -lint "$src" > /dev/null
    say "   $name.plist: lint OK"
    if [ "$apply" = "yes" ]; then
      launchctl bootout "$GUI_DOMAIN/$name" 2>/dev/null || true
      cp "$src" "$dst"
      xattr -c "$dst" 2>/dev/null || true
      launchctl bootstrap "$GUI_DOMAIN" "$dst"
      say "   $name: bootstrapped"
    else
      say "   would bootout+bootstrap $name"
    fi
  done

  say "3) Verification"
  if [ "$apply" = "yes" ]; then
    sleep 2
    launchctl print "$GUI_DOMAIN/$PLIST_MAIN" > /dev/null 2>&1 && say "   $PLIST_MAIN loaded" || say "   WARN: $PLIST_MAIN not loaded"
    launchctl print "$GUI_DOMAIN/$PLIST_HEALTH" > /dev/null 2>&1 && say "   $PLIST_HEALTH loaded" || say "   WARN: $PLIST_HEALTH not loaded"
    bash "$RUNTIME/bin/bridge-start.sh" status || true
  else
    say "   would verify launchctl print + bridge status"
  fi
}

case "$MODE" in
  --dry-run)
    say "DRY RUN (use --apply to act)"
    install_agents no
    ;;
  --apply)
    install_agents yes
    say "Done. Bridge will start via RunAtLoad; to start now: bash $RUNTIME/bin/bridge-start.sh start"
    ;;
  --uninstall)
    say "Uninstalling..."
    launchctl bootout "$GUI_DOMAIN/$PLIST_MAIN" 2>/dev/null || true
    launchctl bootout "$GUI_DOMAIN/$PLIST_HEALTH" 2>/dev/null || true
    rm -f "$AGENTS_DIR/$PLIST_MAIN.plist" "$AGENTS_DIR/$PLIST_HEALTH.plist"
    bash "$RUNTIME/bin/bridge-start.sh" stop 2>/dev/null || true
    say "Uninstalled (runtime dir and data are left in place)"
    ;;
  --status)
    launchctl print "$GUI_DOMAIN/$PLIST_MAIN" 2>/dev/null | head -12 || echo "$PLIST_MAIN: not loaded"
    launchctl print "$GUI_DOMAIN/$PLIST_HEALTH" 2>/dev/null | head -12 || echo "$PLIST_HEALTH: not loaded"
    bash "$RUNTIME/bin/bridge-start.sh" status 2>/dev/null || echo "bridge: not running"
    ;;
  *)
    echo "Usage: $0 [--dry-run|--apply|--uninstall|--status]"
    exit 64
    ;;
esac
