# Eval 設計書: mac-bridge-runtime

## 概要 (Overview)

- 何を測るか: Mac 常駐 Discord ブリッジの稼働不変条件 — 単一応答者・常駐プロセス生存・正しい起動文言・データ書込経路の健全性。
- なぜ重要か: 失敗はユーザーには「Discord で返事が来ない」「二重に返事が来る」「既読・メモが消える」として現れる（T1/T2/T3/T4）。

## 分類 (Classification)

- type: `regression`
- track: `A`（インフラ状態の決定的検査）
- 由来する失敗カテゴリ: T1, T2, T3, T4（`error-analysis/2026-07-06-mac-bridge.md`）

## 成功基準 (Success Criteria)

- `tests/mac-bridge-e2e.sh` が exit 0（全 PASS）。個別基準:
  - `--channels` 付き claude プロセスがこの Mac で**ちょうど 1 個**（T3）
  - tmux socket `claude-bridge` にセッション生存 + pane に `Listening for messages from` プレフィックス（T1/T2）
  - launchd エージェント 2 本（claude-bridge / claude-bridge-health）がロード済み（T2）
  - `~/bochi-data` が実体・`~/.claude/bochi-data` が symlink（T4）
  - Discord API `/users/@me` が 200（トークン健全性）
  - （SSH 到達時）Lightsail access.json の dmPolicy=disabled かつ allowFrom 非空（T3 + 新聞配信生存）
- reference solution: `deploy/mac/setup-bridge.sh --apply` 直後の状態

## データセット (Dataset)

- file: `.evals/datasets/mac-bridge.jsonl`
- 構成: golden (real incidents) 6 / synthetic 0

## Grader（cost hierarchy: code → rule → model → human）

| assertion id | type | logic | threshold | gate? |
|--------------|------|-------|-----------|-------|
| A1 | code | `bash tests/mac-bridge-e2e.sh` exit 0 | — | yes |
| A2 | code | `bash -n deploy/mac/*.sh` 全成功（CI static） | — | yes |
| A3 | rule | plist が `plutil -lint` PASS | — | yes |

## メトリクス (Metrics)

- reliability: `pass^k`（regression-critical。1 回でも FAIL したら赤）

## トレース/再現

- trace source: `~/bochi-data/errors/bridge-watchdog.jsonl`（ブリッジ版 watchdog ログ）+ launchd 標準出力ログ
- 実運用の再起動イベントは watchdog ログに JSONL で残し、次回 error-analysis の入力にする

## 次のステップ

- [x] dataset 作成（golden 6 件）
- [ ] `run` → baseline 受理（リリース時に実施）
