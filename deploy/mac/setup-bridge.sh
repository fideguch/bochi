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
PLIST_NEWS_GEN="com.fideguch.bochi-newspaper-gen"
PLIST_NEWS_DELIVER="com.fideguch.bochi-newspaper-deliver"
ALL_PLISTS="$PLIST_MAIN $PLIST_HEALTH $PLIST_NEWS_GEN $PLIST_NEWS_DELIVER"
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
      "deploy/mac/generate-newspaper.sh:$RUNTIME/bin/generate-newspaper.sh:555" \
      "deploy/mac/deliver-newspaper.sh:$RUNTIME/bin/deliver-newspaper.sh:555" \
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
  for name in $ALL_PLISTS; do
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

  say "3) Discord plugin fast-start patch"
  patch_discord_plugin "$apply"

  say "4) Verification"
  if [ "$apply" = "yes" ]; then
    sleep 2
    for name in $ALL_PLISTS; do
      launchctl print "$GUI_DOMAIN/$name" > /dev/null 2>&1 && say "   $name loaded" || say "   WARN: $name not loaded"
    done
    bash "$RUNTIME/bin/bridge-start.sh" status || true
  else
    say "   would verify launchctl print + bridge status"
  fi
}

patch_discord_plugin() {
  # 2026-07-15 incident: the plugin's start script runs `bun install` on every
  # MCP connect, putting the npm registry on the connect path. Connects took
  # 18-30s and the 04:30 daily restart exceeded claude's 30s startup timeout,
  # leaving the bridge channel-less all day. Patch: preinstall deps here (AOT,
  # where time is free) and strip install from the start script. Idempotent;
  # re-run after plugin version updates (a new cache dir ships the slow script).
  local apply="$1"
  local plugin_root="$HOME/.claude/plugins/cache/claude-plugins-official/discord"
  local ver_dir pkg found=no
  for ver_dir in "$plugin_root"/*/; do
    pkg="$ver_dir/package.json"
    [ -f "$pkg" ] || continue
    found=yes
    if ! grep -q '"start": *"bun install' "$pkg"; then
      say "   $pkg: already patched — skip"
      continue
    fi
    if [ "$apply" = "yes" ]; then
      if ! (cd "$ver_dir" && bun install --no-summary); then
        say "   WARN: bun install failed in $ver_dir — leaving start script unpatched"
        continue
      fi
      cp "$pkg" "$pkg.bak-pre-fast-start"
      /usr/bin/python3 - "$pkg" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
data["scripts"]["start"] = "bun server.ts"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
      say "   patched $pkg (start: bun server.ts; deps preinstalled)"
    else
      say "   would preinstall deps + patch $pkg start script"
    fi
  done
  [ "$found" = yes ] || say "   discord plugin cache not found — skip"
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
    for name in $ALL_PLISTS; do
      launchctl bootout "$GUI_DOMAIN/$name" 2>/dev/null || true
      rm -f "$AGENTS_DIR/$name.plist"
    done
    bash "$RUNTIME/bin/bridge-start.sh" stop 2>/dev/null || true
    say "Uninstalled (runtime dir and data are left in place)"
    ;;
  --status)
    for name in $ALL_PLISTS; do
      launchctl print "$GUI_DOMAIN/$name" > /dev/null 2>&1 && echo "$name: loaded" || echo "$name: not loaded"
    done
    bash "$RUNTIME/bin/bridge-start.sh" status 2>/dev/null || echo "bridge: not running"
    ;;
  *)
    echo "Usage: $0 [--dry-run|--apply|--uninstall|--status]"
    exit 64
    ;;
esac
