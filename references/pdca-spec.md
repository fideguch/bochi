# PDCA Daily Reflection Spec

## Overview

毎朝の新聞配信前に前日の振り返りを実行し、配信品質を改善するゆ。

## Trigger

- Automatically before Mode 2 (newspaper) morning delivery
- Manually: 「PDCA」「振り返り」

## Flow

```
[1] Read yesterday's reflection (if exists)
[2] Read yesterday's newspaper (if exists)
[3] Check user reactions to yesterday's newspaper
[4] Read recent memos (last 7 days, status:open)
[5] Generate today's reflection
[6] Save to ~/bochi-data/reflections/YYYY-MM-DD.md
[7] Apply weight adjustments to user-profile.yaml
```

## Reflection Template

```markdown
# Reflection - YYYY-MM-DD

## Check (前日振り返り)
- Newspaper: N articles delivered, positive: N, negative: N, saved: N, ignored: N
- Engagement rate: N% (target: 60%+)
- Memos: N open, N addressed
- Mode 1 sessions: N (topics created: N)

## Act (課題と対策)
- [Issue identified from Check data]
- [Specific action to address it]

## Plan (今日の方針)
- Focus categories: [based on recent engagement]
- Reduce: [categories with low engagement]
- Open memos to surface: [list relevant open memos]

## Intake Gate Review
- Items memorized this week: N
- Items referenced: N (rate: N%)
- Target reference rate: 60%+
- Threshold adjustment: [if needed]

## Newspaper Curation Hints
- [Specific guidance for today's newspaper based on PDCA]
```

## Weight Adjustment Rules

Applied via Edit tool to user-profile.yaml:

| Signal | Adjustment |
|--------|------------|
| リアクション2個以上 | category weight +0.08 |
| Mode 1 deep dive from category | category weight +0.08 |
| ユーザー明示的指示（「〇〇の重み下げて」） | 指定カテゴリを手動調整 |

ペナルティは存在しない。ウェイトは上がるのみ（SKILL.md Feedback Signal準拠）。
Weight bounds: min 0.1, max 1.0

## Freshness Check (Weekly)

On Mondays, also check:
- Active items >90 days without reference -> demote to Warm
- Warm items >180 days -> propose Archive to user
- Log demotions in reflection file

## Edge Cases

- **First run (no yesterday data)** → Check phaseスキップ、Plan-only reflectionを生成
- **user-profile.yaml missing** → デフォルト値（全カテゴリweight 0.3）で自動作成
- **Weight adjustment exceeds max 1.0** → 1.0でキャップ、ログに上限到達を記録
- **Zero engagement data for the week** → reflectionに記載、weight未調整、コンテンツ多様化を提案
