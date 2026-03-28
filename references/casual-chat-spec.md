# Mode 3: Casual Chat Spec

## Overview

過去トピックの進展追跡とセレンディピティで思考の幅を広げるゆ。

## Trigger

「雑談」「何か面白い？」「ぼちぼち話そう」「暇」

## Flow

```
[Trigger: casual chat]
  |
  [1] Load user-profile.yaml + seen.jsonl + cache/trending/ (並列Read)
  [2] Build 2 streams IN PARALLEL:
      |
      +-- Related Stream (2-3 items)
      |   [a] Check cache/trending/*.jsonl for cached items (TTL < 12h)
      |   [b] Filter out seen.jsonl entries (既読排除)
      |   [c] If cache sufficient → use cached items (WebSearch不要)
      |   [d] If cache empty/stale → Read index.jsonl -> topics from last 30d
      |       → WebSearch "{topic title} latest update" → filter seen → select
      |
      +-- Serendipity Stream (1-2 items)
      |   Find lowest-weight categories in user-profile
      |   WebSearch trending topics in those categories
      |   Filter out seen.jsonl entries
      |   Select 1-2 surprising/cross-domain items
      |
  [3] Present 3-5 items total
  [4] Append all presented article URLs to seen.jsonl
  [5] Collect user reactions → update profile weights (positive only)
  [6] Check cache/trending/ remaining count → if < 3 per category, background replenish
```

## Output Format

```
ぼちぼち面白い話があるゆ 💫

## 前に話したやつの続報 🌟
1. **{トピックタイトル}** — {新しい展開1文} (E-E-A-T:{score})
   前回: {date}に話した内容の要約
2. ...

## こんなのもあるゆ ✨
1. **{意外なトピック}** — {なぜ面白いか1文} (E-E-A-T:{score})
   {ユーザーの既存興味との接点を1文で説明}

気になるのあったら深掘りするゆ！📌で保存もできるゆ 💗
```

## Reaction Handling

Positive-only weights (see newspaper-spec.md):
- リアクション1個 → 会話継続シグナル（seen.jsonlに記録）
- リアクション2個以上 → カテゴリweight +0.08
- "もっと聞かせて" / "深掘り" → transition to Mode 1 + カテゴリweight +0.08
- ペナルティは存在しない。ウェイト下げはユーザーの明示的指示のみ

## Related Stream Selection

Priority for "related" items:
1. Topics with status:open memos (actionable follow-ups)
2. Topics in high-weight categories
3. Topics with recent web activity (new articles found)

Skip topics already in today's newspaper to avoid duplication.

## Serendipity Stream Selection

Goal: expand user's peripheral vision.
- Pick from categories with weight < 0.4
- Cross-reference with user's high-weight categories for unexpected connections
- Example: User is PM-heavy -> surface a design trend that impacts PM decisions

## Transition to Mode 1

When user shows interest in an item:
1. Extract the topic/URL
2. Start Mode 1 Phase A with that context
3. Tag resulting topic with `source: casual-chat`
