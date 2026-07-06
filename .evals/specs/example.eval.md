# Eval 設計書: <feature-name>

> `templates/eval-spec.md` から生成。`.evals/specs/<feature>.eval.md` に保存する。
> 1 ファイル = 1 つの評価対象。Phase 1 の taxonomy の上位失敗から起こすこと。

## 概要 (Overview)
- 何を測るか（1-2 文）:
- なぜ重要か（影響・ビジネス上のコスト）:

## 分類 (Classification)
- type: `capability` | `regression`
- track: `A` (output/artifact) | `B` (agent/skill behavior)
- 由来する失敗カテゴリ (from `error-analysis/`): <taxonomy-id>

## 成功基準 (Success Criteria — measurable & unambiguous)
- [ ] 2 人のレビュアーが独立に同じ pass/fail に到達できる粒度か
- 基準: 例「出力に X が含まれ、かつ Y が起きない」
- reference solution（解けることの証明）: <path or note>

## データセット (Dataset)
- file: `.evals/datasets/<feature>.jsonl`
- 構成: golden (real) <N> / from_traces <N> / synthetic (capability seeding のみ) <N>
- balance: pass/fail を分布全体にわたって配置（理想 ~50:50）

## Grader（cost hierarchy: code → rule → model → human）
| assertion id | type | logic | threshold | gate? |
|--------------|------|-------|-----------|-------|
| A1 | code | exit code of `npm test` == 0 | — | yes |
| A2 | rule | output is valid JSON matching schema | — | yes |
| A3 | model | binary judge `<criterion>.judge.md` | TPR/TNR≥0.8 | only if VALIDATED |

> deterministic を最優先。model judge は subjective な失敗にのみ、かつ検証済み(`VALIDATED`)のときだけ gate。

## メトリクス (Metrics)
- reliability: `pass@k` (capability) / `pass^k` (regression-critical)
- 非決定 assertion の gate: `mean − k·stddev < threshold`（k は config.json）

## トレース/再現 (Track B のみ)
- trace source: `~/.claude/projects/<hash>/*.jsonl` | git bug-fix | CI log
- grade: outcome（最終状態）。trajectory は診断用に記録のみ。

## 次のステップ (Next Steps)
- [ ] dataset を作成 / 収集
- [ ] judge が必要なら構築・検証 (`judge` mode)
- [ ] `run` → `report` → baseline 受理 (`accept-baseline`)
