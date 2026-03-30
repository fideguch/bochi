# Mode 3: Casual Chat Spec

## Overview

過去トピックの進展追跡とセレンディピティで思考の幅を広げるゆ。

## Trigger

「おすすめ」「何か面白い？」「ぼちぼち話そう」「暇」

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
  [4] Append all presented article URLs to seen.jsonl   ← HARD-GATE (below)
  [5] Collect user reactions → update profile weights (positive only)
  [6] Check cache/trending/ remaining count → if < 3 per category, background replenish
```

## Output Format

E-E-A-Tスコアや内部ロジック名は表面に出さない。裏で評価し、表はあくまで自然な会話。

```
ねえねえ、ちょっと面白いの見つけたゆ 💫

あのさ、前に話してた{トピック名}の話なんだけど — {新しい展開を会話口調で1文}
これ{ユーザーの関心との接点}と繋がると思うゆ 🌟

あと、{ユーザーの最上位カテゴリ}で気になったのがあってゆ:
**{記事タイトル}** — {なぜこのユーザーが気になりそうかを1文}

{最下位weightカテゴリからの意外な話題}も面白かったゆ ✨
{ユーザーの既存興味との意外な接点を会話口調で}

どれか気になるのあるゆ？深掘りしちゃうゆ 💗
```

### 表面と内部の分離

| ユーザーが見るもの | 内部で起きていること |
|-----------------|------------------|
| 「前に話してた〇〇の話」 | index.jsonl → topics/status:open → WebSearch latest |
| 「これ絶対好きだと思う」 | user-profile.yaml top weight category → E-E-A-T ≥ 24/40 |
| 「こんなのも面白かった」 | lowest weight category → cross-domain serendipity |
| 「どれか気になる？」 | reaction待ち → weight更新トリガー |

## Data Persistence (HARD-GATE)

<HARD-GATE>
記事提示後、Discord reply送信前に以下を**必ず実行**する。
スキップすると同じ記事が何度も提示され、学習蓄積が機能しない。

1. Read `/home/ubuntu/bochi-data/seen.jsonl` で既存内容を取得
2. 提示した全URLのJSONL行を末尾に追加:
   `{"url":"...","seen_at":"YYYY-MM-DD","source":"casual","title":"..."}`
3. Write tool で `/home/ubuntu/bochi-data/seen.jsonl` に書き出し

※ Bash `echo >>` は使用禁止（Permission制御でブロックされる。lightsail-claude.md Write Method準拠）
seen.jsonlに記録しない限り、次回の「おすすめ」で同じ記事が再表示される。
</HARD-GATE>

## Discord File Attachment

メモ保存時にDiscord DMにファイルを添付する:

1. memos/YYYY-MM-DD-slug.md 保存完了後
2. reply の files パラメータで添付: `files: ["/home/ubuntu/bochi-data/memos/YYYY-MM-DD-slug.md"]`
3. テキスト例: 「残しとくゆ ✨」（ファイル内容の説明は不要、ユーザーがファイルを開いて読む）
4. ファイル内にBot発言を含めない

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

## Edge Cases
- index.jsonlが空 or 読み取りエラー → 「まだデータがないゆ。最初のトピックを作るゆ？💫」
- 全関連トピックがarchive → 「最近の話題がないゆ。何か面白いこと調べるゆ？✨」
- ユーザーが1文字だけ入力 → bochiキャラで自然に返す（Mode強制しない）
- 連続メッセージで先行応答が中断された場合 → Claude Code単一セッション制約。後着メッセージを処理後、「さっきのも気になるゆ？もう一回聞いてゆ 💫」と自然にフォロー
