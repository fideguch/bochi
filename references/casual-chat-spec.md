# Mode 3: Casual Chat Spec

## Overview

過去トピックの進展追跡とセレンディピティで思考の幅を広げるゆ。

## Trigger

「雑談」「何か面白い？」「ぼちぼち話そう」「暇」

## Flow

```
[Trigger: casual chat]
  |
  [1] Load user-profile.yaml
  [2] Build 2 streams:
      |
      +-- Related Stream (2-3 items)
      |   Read index.jsonl -> topics from last 30 days (freshness: active)
      |   For each: WebSearch "{topic title} latest update {date}"
      |   Select top 2-3 with new developments
      |
      +-- Serendipity Stream (1-2 items)
      |   Find lowest-weight categories in user-profile
      |   WebSearch trending topics in those categories
      |   Select 1-2 surprising/cross-domain items
      |
  [3] Present 3-5 items total
  [4] Collect user reactions -> update profile weights
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

Same as newspaper (see newspaper-spec.md):
- Positive -> category weight +0.05
- Negative -> category weight -0.05
- Save (📌) -> create memo + weight +0.03
- "もっと聞かせて" / "深掘り" -> transition to Mode 1

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
