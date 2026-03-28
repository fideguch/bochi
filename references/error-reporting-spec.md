# Error Reporting Spec

bochi が Discord メッセージに返答できなかった場合のエラー報告仕様。

## 原則

ユーザーが Discord DM を送って返答がなかった場合、原因がわからないのが最悪の体験。
**沈黙は許容しない** — 何かしらのフィードバックを必ず返す。

## Error Handling Flow

```
Discord Message Received
  |
  [React 👀] ← 受信確認（即座）
  |
  [Process Message]
  |
  +-- Success → Reply normally
  |
  +-- Error caught
        |
        [Classify Error]
        +-- RECOVERABLE (retry possible)
        |     → Retry once with simplified prompt
        |     → If retry fails → report to user
        |
        +-- NON-RECOVERABLE (MCP fail, auth error, rate limit)
        |     → Report to user immediately
        |
        +-- TIMEOUT (processing took >60s with no output)
              → Report to user with timeout notice
```

## Error Report Format (Discord Reply)

```
⚠️ ごめんゆ、うまく返答できなかったゆ...

原因: {error_category}
詳細: {brief_description}

対処: {suggested_action}
```

### Error Categories

| Category | Message | Suggested Action |
|----------|---------|-----------------|
| `mcp_failure` | Discord MCP サーバーが応答しないゆ | サーバー再起動が必要かもゆ |
| `rate_limit` | API のレート制限に引っかかったゆ | 少し待ってからもう一度試してゆ |
| `auth_error` | 認証エラーが発生したゆ | サーバー側の認証設定を確認してゆ |
| `timeout` | 処理に時間がかかりすぎたゆ | もう少しシンプルな質問で試してゆ |
| `unknown` | 予期しないエラーが起きたゆ | エラーログを記録したゆ。次回起動時に調査するゆ |

## Error Logging

エラー発生時、以下のファイルに記録:

```
~/.claude/bochi-data/errors/YYYY-MM-DD.jsonl
```

### Entry Format

```jsonl
{"ts":"ISO8601","category":"mcp_failure|rate_limit|auth_error|timeout|unknown","message":"error message","discord_msg_id":"...","user":"...","input_preview":"first 100 chars...","resolved":false}
```

## Edge Cases

- **Discord reply tool itself fails** → ログのみ記録（Implementation Notes §3準拠）
- **Error log file write fails** → /tmp にフォールバック書き込み、次セッションで報告
- **Rapid error storm (5+ errors in 60s)** → 単一レポートにバッチ化、Discord DM洪水を防止
- **Error category ambiguous** → "unknown" にデフォルト、フルスタックをログに記録

## Implementation Notes

- Error reporting は bochi SKILL.md の Default Handler に組み込む
- Discord reply tool が使えない場合（MCP自体が死んでいる場合）はログのみ記録
- ログファイルは S3 sync 対象に含める（bochi-data/ 配下のため自動）
