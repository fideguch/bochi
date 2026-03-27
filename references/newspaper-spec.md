# Mode 2: Newspaper Spec

## Overview

毎朝08:00 JSTにユーザーの興味カテゴリに基づくニュースキュレーションを配信するゆ。
ChatGPT Pulse / Dume.ai パターン準拠。

## Flow

```
[Trigger: "新聞" or RemoteTrigger bochi-daily]
  |
  [1] Load user-profile.yaml -> interests.categories
  [2] Run PDCA (references/pdca-spec.md) if morning trigger
  |
  [3] For each category (top 5 by weight):
      WebSearch "{category} {date} news trends"
      -> E-E-A-T evaluate each result
      -> Select top 3 articles per category
  |
  [4] Format output (see Output Format below)
  [5] Save to ~/.claude/bochi-data/newspaper/YYYY-MM-DD.md
  [6] Append to index.jsonl
  [7] Wait for user reactions -> update profile weights
```

## Output Format (Console)

```
おはようゆ！今日の新聞ゆ 💗

## PM / Product ✨
1. [タイトル](URL) (E-E-A-T:32) — 1文要約
2. [タイトル](URL) (E-E-A-T:29) — 1文要約
3. [タイトル](URL) (E-E-A-T:28) — 1文要約

## AI / ML 🌟
1. ...

## Technology 💫
1. ...

(5 categories total)

気になる記事があったら教えてゆ！深掘りするゆ 🫶
```

Emoji decoration: randomly select from 💗🥰✨💋🫶💕😘🌟💫🎀 per category.
Vary the pattern each day.

## Feedback Loop

User reactions (natural language or emoji):
- Positive (😍👍❤️🔥 or "いいね", "面白い"): category weight +0.05
- Negative (👎😐 or "微妙", "いらない"): category weight -0.05
- Save (📌🔖💡 or "保存", "後で"): create auto memo + weight +0.03
- 3 consecutive days skipped category: weight -0.1

Weight updates: Edit user-profile.yaml via Edit tool.

## Article Selection Criteria

- E-E-A-T score >= 24/40 (slightly lower than Mode 1 for breadth)
- Published within 7 days
- No duplicate URLs across last 7 newspapers
- Prefer sources from trusted-domains.md and learned-sources.md

## File Output (Professional Mode)

Save to `~/.claude/bochi-data/newspaper/YYYY-MM-DD.md`:

```markdown
# Daily Brief - YYYY-MM-DD

## Categories & Articles

### PM / Product
| # | Title | URL | E-E-A-T | Summary |
|---|-------|-----|---------|---------|
| 1 | ... | ... | /40 | ... |

(repeat per category)

## Profile Weight Changes
- PM: 0.80 (no change)
- AI: 0.70 -> 0.75 (+0.05, positive reaction)
```

## Index Entry

```bash
echo '{"id":"news-YYYYMMDD","type":"newspaper","title":"Daily Brief YYYY-MM-DD","date":"YYYY-MM-DD","category":"newspaper","tags":[],"freshness":"active","channel":"cli","path":"newspaper/YYYY-MM-DD.md"}' >> ~/.claude/bochi-data/index.jsonl
```

## Deep Dive Transition

When user says "深掘りして" about a specific article:
1. Extract URL and topic from the article
2. Transition to Mode 1 (Phase A) with the article as input
3. Tag the resulting topic with `source: newspaper`
