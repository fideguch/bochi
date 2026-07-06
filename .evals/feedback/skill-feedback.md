# Eval フィードバック（駆動スキル/エージェント向け）: <date>

> `gen-feedback.sh` が生成。対象 = このプロジェクトを駆動するスキル/エージェントの行動。
> `.evals/feedback/skill-feedback.md`。**提案のみ。自動編集しない。** provenance 必須。

## 対象 (Scope)
- monitored skills: <list from config.json>
- scope: `project-local`（既定）。`~/.claude` への変更は `--global` 指定時のみ + 強警告。

## 失敗の帰属 (Attribution — evidence schema)
> confidence が閾値（config: attribution_confidence_min）未満なら `unknown` とし、提案しない。

```json
{
  "failure_id": "EA-<date>-NNN",
  "active_skills": ["forge_ace", "gatekeeper"],
  "loaded_instructions": ["forge_ace SKILL.md Step 5", "gatekeeper HG-5"],
  "transcript_ref": "~/.claude/projects/<hash>/<uuid>.jsonl#Lxxxx-Lyyyy",
  "tool_calls": ["Edit(...)", "Bash(npm test)"],
  "observed_violation": "<what the agent/skill did wrong>",
  "alternative_causes": ["flaky test", "stale cache"],
  "confidence": 0.00
}
```

## 改善提案（スキル/CLAUDE.md へのパッチ案）
> 各提案は (1) 根拠 provenance（assertion id + transcript ref）, (2) 対象ファイル,
> (3) `git apply` 可能な diff を含む。適用はユーザー判断。

### 提案 1 — <skill> / <file>
- 根拠: <failure_id>, <assertion id>, <transcript_ref>
- confidence: 0.__
- diff:
  ```diff
  --- a/<path>
  +++ b/<path>
  @@
  - <old instruction>
  + <improved instruction>
  ```

## in-session（現セッションのエージェントへの直接フィードバック）
- 根本原因: <...>
- 次にとるべき行動: <...>
- （任意）evaluator-optimizer による即時修正を実施したか: yes/no

## learnings への反映
- [ ] `learnings.md` に蒸留した教訓を追記（cap 超過分は archive へ）
- [ ] 対象 `CLAUDE.md` に `@.evals/feedback/learnings.md` の import 行を提案
