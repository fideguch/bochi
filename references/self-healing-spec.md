# Self-Healing Spec

bochi の自己診断・自動修復サイクル仕様。
セッション再起動時に前回エラーを調査し、品質向上を継続的に行う。

## 原則

**「壊れたままにしない」** — エラーが起きたら記録し、次の機会に調査し、可能なら自動修復する。
このサイクルを回すことで、bochi は使うほど安定する。

## Session Start Health Check

```
Session Start (tmux restart / cron reboot / manual start)
  |
  [Check Error Log]
  ~/.claude/bochi-data/errors/*.jsonl
  |
  +-- No unresolved errors → normal startup
  |
  +-- Unresolved errors found
        |
        [Investigate]
        1. Read error entries where resolved=false
        2. Group by category
        3. For each category:
           |
           +-- mcp_failure → check `bun --version`, MCP server status
           +-- rate_limit → check time since last error (cooldown ok?)
           +-- auth_error → check credential files exist and are valid
           +-- timeout → check system resources (memory, CPU)
           +-- unknown → read error message, search for known patterns
        |
        [Generate Diagnosis Report]
        → Save to ~/.claude/bochi-data/errors/diagnosis-YYYY-MM-DD.md
        |
        [Auto-fix if possible]
        +-- PATH issue → verify symlinks (/usr/local/bin/bun etc.)
        +-- Stale credentials → flag for user action
        +-- Disk full → suggest cleanup
        +-- Known bug pattern → apply documented workaround
        |
        [Mark resolved]
        → Update resolved=true in error JSONL for fixed issues
        |
        [Report to Owner]
        → If Discord MCP is available, send summary to owner
        → Format: "前回のエラーを調査したゆ。{summary}"
```

## Diagnosis Report Format

```markdown
# bochi Health Diagnosis — YYYY-MM-DD

## Unresolved Errors (since last check)

| Time | Category | Message | Auto-fixable? |
|------|----------|---------|--------------|
| ... | ... | ... | Yes/No |

## Root Cause Analysis

{category}: {root cause description}

## Actions Taken

- [x] {auto-fix applied}
- [ ] {requires user action}: {what to do}

## Recommendations

- {preventive measure}
```

## Periodic Health Check (via RemoteTrigger)

bochi-daily trigger (08:00 JST) に health check を組み込む:

```
bochi-daily trigger
  |
  [Morning Newspaper] (existing)
  |
  [Health Check] (new, append to trigger)
  +-- Check error log for last 24h
  +-- Check system resources
  +-- Check Discord MCP connectivity
  +-- If issues found → include in morning report
```

## Continuous Improvement Cycle

```
Error occurs → Log (error-reporting-spec.md)
     ↓
Next session start → Investigate (this spec)
     ↓
Diagnosis → Auto-fix or flag for user
     ↓
Pattern emerges (3+ same category in 7 days)
     ↓
Create preventive measure:
  - Hook script for early detection
  - SKILL.md rule update
  - Infrastructure change recommendation
     ↓
Track improvement in errors/diagnosis-*.md
```

## Error Pattern Database

既知のエラーパターンと対処法を蓄積:

```
~/.claude/bochi-data/errors/known-patterns.jsonl
```

### Entry Format

```jsonl
{"pattern":"bun: command not found","category":"mcp_failure","root_cause":"bun not in PATH for non-login shell","fix":"sudo ln -sf ~/.bun/bin/bun /usr/local/bin/bun","first_seen":"2026-03-28","occurrences":1}
```

初回エラー: 今回の bun PATH 問題を seed として登録。

## Implementation Priority

1. **P0**: Error logging (error-reporting-spec.md) — 全エラーを記録
2. **P1**: Session start health check — 未解決エラーの調査
3. **P2**: Auto-fix for known patterns — 既知パターンの自動修復
4. **P3**: Pattern detection — 繰り返しパターンの検出と予防策提案
5. **P4**: Morning report integration — 日次ヘルスチェック

---

## JSONL Recovery

index.jsonl破損時（不完全行、JSON parse失敗）の回復手順:

1. 最終行を `tail -1` で取得
2. `python3 -c "import json; json.loads(input())"` で検証
3. 失敗 → 最終行を `sed -i '' '$d'`（macOS）/ `sed -i '$d'`（Linux）で削除
4. 再検証 → 成功するまで繰り返し（最大5行）
5. 削除した行は `errors/jsonl-recovery-YYYY-MM-DD.log` に記録
6. 回復完了後、Session Start Health Checkが自動で整合性を確認

**自動回復スクリプト例:**
```bash
FILE=~/.claude/bochi-data/index.jsonl
for i in $(seq 1 5); do
  if tail -1 "$FILE" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
    echo "JSONL valid after removing $((i-1)) lines"
    break
  fi
  tail -1 "$FILE" >> ~/.claude/bochi-data/errors/jsonl-recovery-$(date +%F).log
  sed -i '' '$d' "$FILE"
done
```
