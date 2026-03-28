# Skill Tracking Spec

## Overview

ユーザーのスキル使用パターンを追跡し、頻用スキルの提案や自作スキル管理を行うゆ。

## Data Storage

- Usage stats: `~/.claude/bochi-data/stats/usage.jsonl` (Bash `echo >>`)
- Custom skills list: `user-profile.yaml` -> `custom_skills` array

## Usage Entry Format

```jsonl
{"date":"2026-03-28","skill":"requirements_designer","mode":"cli","duration_approx":"long","outcome":"completed"}
```

Fields:
- `date`: YYYY-MM-DD
- `skill`: skill name (from /skill invocation or detected)
- `mode`: cli | discord
- `duration_approx`: short (<5min) | medium (5-30min) | long (>30min)
- `outcome`: completed | abandoned | error

## Custom Skill Detection

On session start or when asked:

```bash
# List user's skill repos
gh repo list --limit 50 | grep -i skill

# List local skills
ls ~/.claude/skills/
```

Pattern match for SKILL.md files to identify custom skills.
Update `user-profile.yaml` -> `custom_skills` via Edit tool.

## Weekly Summary (in PDCA)

```
## Skill Usage This Week
- Top 5: requirements_designer (4x), bochi (3x), pm-data-analysis (2x), ...
- Custom skills used: 3/8
- New skill discovered: pm-context-engineering-advisor
```

## Discord Skill Invocation

User sends skill name in Discord (natural language or shorthand):

```
[Discord] User: "req-designerで要件定義"
  |
  bochi: fuzzy match "req-designer" -> "requirements_designer"
  |
  bochi: "requirements_designerを起動するゆ！コンテキストは？💫"
```

Fuzzy matching priority:
1. Exact match
2. Prefix match (req-designer -> requirements_designer)
3. Japanese description match (要件定義 -> requirements_designer)
4. Top usage frequency (disambiguate ties)

## Proactive Suggestions

Based on usage patterns:
- "最近PM系スキルをよく使ってるゆ。pm-roadmap-planningも試してみるゆ？"
- "requirements_designerの後はいつもspeckit-bridge使ってるゆ。自動で繋ぐゆ？"

Trigger: Mode 3 (casual chat) or Mode 2 (newspaper) footer.

## Edge Cases

- **usage.jsonl missing** → 初回スキル呼び出し時に自動作成
- **gh CLI not authenticated** → リポスキャンをスキップ、ローカル ~/.claude/skills/ のみ使用
- **Fuzzy match returns multiple equal-score candidates** → 上位3件を提示、ユーザーに選択を依頼
- **Custom skill SKILL.md malformed** → スキャンからスキップ、警告をログ
