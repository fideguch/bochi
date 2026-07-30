#!/bin/bash
# generate-newspaper.sh — produce today's bochi newspaper on the Mac.
# Runs a headless `claude -p` in the bridge runtime (inherits its allow rules:
# WebSearch + Write to ~/bochi-data), writing a well-formed dated file that
# send-newspaper-to-discord.py can parse. Idempotent; never leaves a partial
# file (delivery then skips rather than sending a stale one).
#
# Scheduled ~06:20 JST by com.fideguch.bochi-newspaper-gen; delivery is a
# separate ~08:00 JST job.
set -uo pipefail

RUNTIME="/Users/fumito_ideguchi/bochi-runtime"
DATA="/Users/fumito_ideguchi/bochi-data"
NEWS_DIR="$DATA/newspaper"
LOG="$DATA/errors/newspaper-gen.log"
CLAUDE_BIN="/Users/fumito_ideguchi/.local/bin/claude"
DELIVER="$RUNTIME/bin/deliver-newspaper.sh"
NOTIFY="$RUNTIME/bin/notify-owner.sh"

# Deliver as soon as an issue exists, instead of trusting the clock.
# The old design coupled the two jobs by time (generate 06:20 JST, deliver
# 08:00 JST) and assumed generation finishes inside 1h40m. On a laptop that
# sleeps mid-run it does not: on 2026-07-30 generation took 2h11m of wall clock
# (frozen while asleep) and the delivery job ran 8m35s too early, found no file,
# skipped, and that issue was never sent. deliver-newspaper.sh is idempotent via
# a per-day marker, so the 08:00 job stays as a backstop.
deliver_now() {
  [ -x "$DELIVER" ] || { log "deliver script missing ($DELIVER) — 08:00 backstop only"; return; }
  if "$DELIVER" >> "$LOG" 2>&1; then
    log "delivery triggered inline (ok)"
  else
    log "delivery triggered inline (rc=$? — backstop will retry)"
  fi
}

export PATH="/Users/fumito_ideguchi/.local/bin:/Users/fumito_ideguchi/.bun/bin:/Users/fumito_ideguchi/.nodebrew/current/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CLAUDE_BRIDGE=1

DATE=$(TZ=Asia/Tokyo date +%Y-%m-%d)
OUT="$NEWS_DIR/$DATE.md"
BUILD="$NEWS_DIR/.$DATE.building.$$.md"   # write here first; publish atomically
mkdir -p "$NEWS_DIR" "$(dirname "$LOG")"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$LOG"; }

# Count article rows (| 1 | ... |). grep -c prints 0 AND exits 1 on no match,
# which previously fired the `|| echo 0` fallback and emitted two zeroes.
count_rows() {
  [ -f "$1" ] || { echo 0; return; }
  local n
  n=$(grep -cE '^\| *[0-9]+ *\|' "$1" 2>/dev/null) || true
  echo "${n:-0}"
}

log "--- generate start ($DATE) ---"

if [ -s "$OUT" ] && [ "$(count_rows "$OUT")" -ge 5 ]; then
  log "already generated ($(count_rows "$OUT") rows) — skip generation"
  # Still attempt delivery: a re-run (launchd retry after a sleep-deferred
  # window) may be the first chance an existing-but-undelivered issue gets sent.
  # The marker makes this a no-op once it has actually gone out.
  deliver_now
  exit 0
fi

PROMPT=$(cat <<PROMPT_EOF
今日（${DATE} JST）の bochi 朝刊を生成して、ファイルに書き出してください。会話・Discord送信はしません（これはバックグラウンド生成ジョブです）。

手順:
1. /Users/fumito_ideguchi/bochi-data/user-profile.yaml を読み、興味カテゴリ（weight 上位5つ）を把握
2. /Users/fumito_ideguchi/bochi-data/seen.jsonl を読み、既読URL集合を作る（無ければ空）
3. 各カテゴリについて WebSearch で「{カテゴリ} 最新ニュース ${DATE}」等を検索し、7日以内・既読でない記事から E-E-A-T 28/40 以上を目安に上位3件を選ぶ
4. 次の Markdown 形式で **Write ツールを使って** ${BUILD} に書き出す（この実パスを使うこと。~/.claude/ 配下は使わない。公開用の最終ファイルは別プロセスが原子的に配置する）:

# Daily Brief - ${DATE}

## Categories & Articles

### {カテゴリ名}
| # | Title | Source | E-E-A-T | Summary |
|---|-------|--------|---------|---------|
| 1 | {短い日本語タイトル} | [{ドメイン}]({URL}) | {score}/40 | {1文要約} |
| 2 | ... |
| 3 | ... |

（カテゴリごとに繰り返す。5カテゴリ）

5. 配信した全記事URLを /Users/fumito_ideguchi/bochi-data/seen.jsonl に追記（Read→末尾追加→Write。1行 = {"url":"...","seen_at":"${DATE}","source":"newspaper","title":"..."}）
6. 完了したら「generated N articles across M categories」とだけ出力

重要:
- ファイルは必ず上記の表形式（各記事行は | 1 | タイトル | [ドメイン](URL) | 32/40 | 要約 | の5セル）にすること。配信スクリプトがこの形式をパースする。
- Discord には送信しない。
- 語尾「ゆ」等のキャラクター口調はファイルに含めない（プロフェッショナルモード）。
PROMPT_EOF
)

# Clean up stale build files from earlier failed runs (never delivered:
# delivery only reads exactly <today>.md, and these are dotfiles).
find "$NEWS_DIR" -maxdepth 1 -name ".*.building.*.md" -mmin +180 -delete 2>/dev/null || true

cd "$RUNTIME" || exit 1
echo "$PROMPT" | "$CLAUDE_BIN" -p --model sonnet >> "$LOG" 2>&1
RC=$?
log "claude -p exit=$RC"

# Validate the BUILD file, then publish atomically. delivery reads only $OUT,
# so it can never observe a half-written or malformed issue.
ROWS=$(count_rows "$BUILD")
if [ -s "$BUILD" ] && [ "$ROWS" -ge 5 ] && grep -q '^# Daily Brief' "$BUILD"; then
  mv -f "$BUILD" "$OUT"        # atomic within the same directory
  log "--- generate ok ($ROWS rows, published) ---"
  deliver_now
  exit 0
fi

# Malformed / missing build → keep aside for debugging, never publish.
# Notify the owner: a silent failure here is how 2026-07-27 lost its issue with
# nobody noticing for two days (claude -p exit=1, no alert anywhere).
if [ -f "$BUILD" ]; then
  mv -f "$BUILD" "$BUILD.partial" 2>/dev/null || rm -f "$BUILD"
  log "build malformed ($ROWS rows) — not published; delivery will skip"
  REASON="生成物の形式が不正（記事行 ${ROWS} 行）"
else
  log "no build file produced (claude exit=$RC) — delivery will skip"
  REASON="生成物が作られなかった（claude -p exit=${RC}）"
fi
if [ -x "$NOTIFY" ]; then
  "$NOTIFY" newspaper-gen-failed "${DATE} の朝刊生成に失敗しました: ${REASON}。ログ: ~/bochi-data/errors/newspaper-gen.log" >/dev/null 2>&1 || true
fi
exit 1
