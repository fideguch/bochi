# Mode 2: Newspaper Spec

## Overview

毎朝08:00 JSTにユーザーの興味カテゴリに基づくニュースキュレーションを配信するゆ。
ChatGPT Pulse / Dume.ai パターン準拠。

## Flow (2-Pass Architecture)

### Background Pass (RemoteTrigger bochi-prefetch, 06:00 JST)

```
[1] Load user-profile.yaml -> interests.categories (top 5 by weight)
[2] Load seen.jsonl -> build seen URL set
[3] For each category IN PARALLEL:
    WebSearch "{category} {date} news trends"
    -> Filter out seen URLs
    -> If insufficient after filter → additional WebSearch to replenish
    -> E-E-A-T evaluate (>= 24/40)
    -> Select top 3 per category
[4] Save to cache/newspaper-draft.md + cache/trending/*.jsonl
[5] Update cache/meta.json: newspaper_generated_at = now()
```

### Delivery Pass (ユーザー "新聞" or RemoteTrigger bochi-daily 08:00 JST)

```
[1] Check cache/meta.json
    +-- newspaper_generated_at is today → Read cache/newspaper-draft.md
    +-- Stale or missing → Fallback to on-demand generation (Background Pass inline)
[2] Run PDCA (references/pdca-spec.md) if morning trigger
[3] Format output (see Output Format below)
[4] Append all delivered article URLs to seen.jsonl    ← HARD-GATE (below)
[5] Save to newspaper/YYYY-MM-DD.md + index.jsonl     ← HARD-GATE (below)
[6] Collect user reactions → update profile weights (positive only)
```

## Output Format (Console)

```
おはようゆ！今日の新聞ゆ 💗

## PM / Product ✨
1. オンボーディング自動化でチャーン率30%改善 — [note.com](URL) (32)
2. PLG企業のプライシング最新動向 — [hbr.org](URL) (29)
3. B2Bプロダクト発見の5ステップ — [lenny.substack.com](URL) (28)

## AI / ML 🌟
1. ...

## Technology 💫
1. ...

(5 categories total)

気になる記事があったら教えてゆ！深掘りするゆ 🫶
```

Emoji decoration: randomly select from 💗🥰✨💋🫶💕😘🌟💫🎀 per category.
Vary the pattern each day.

## Feedback Loop (Positive-Only Weights)

ペナルティは存在しない。ウェイトは上がるのみ。

| ユーザー行動 | weight変更 |
|------------|-----------|
| リアクション1個 | なし（会話継続シグナルとして記録） |
| リアクション2個以上 | カテゴリweight +0.08 |
| 「深掘りして」でMode 1遷移 | カテゴリweight +0.08 |
| 「〇〇の重み下げて」等 | 指定カテゴリのweight手動調整（ユーザー明示的指示のみ） |

Weight updates: Edit user-profile.yaml via Edit tool.

## Article Selection Criteria

- E-E-A-T score >= 24/40 (slightly lower than Mode 1 for breadth)
- Published within 7 days
- **NOT in seen.jsonl**（既読記事は絶対に再表示しない）
- 既読フィルタ後に不足 → 追加WebSearchで補充
- Prefer sources from trusted-domains.md and learned-sources.md

## File Output (Professional Mode)

Save to `~/.claude/bochi-data/newspaper/YYYY-MM-DD.md`:

```markdown
# Daily Brief - YYYY-MM-DD

## Categories & Articles

### PM / Product
| # | Title | Source | E-E-A-T | Summary |
|---|-------|--------|---------|---------|
| 1 | {1語〜短文の要約} | [{domain}](URL) | /40 | {1文要約} |

(repeat per category)

## Profile Weight Changes
- PM: 0.80 (no change)
- AI: 0.70 -> 0.75 (+0.05, positive reaction)
```

## Index Entry

```bash
echo '{"id":"news-YYYYMMDD","type":"newspaper","title":"Daily Brief YYYY-MM-DD","date":"YYYY-MM-DD","category":"newspaper","tags":[],"freshness":"active","channel":"cli","path":"newspaper/YYYY-MM-DD.md"}' >> ~/.claude/bochi-data/index.jsonl
```

## Data Persistence (HARD-GATE)

<HARD-GATE>
新聞配信後、Discord reply送信前に以下を**必ず実行**する。
スキップすると「脳」にデータが残らず、既読管理・アーカイブ・PDCAが全て破綻する。

1. `echo '{"url":"...","seen_at":"YYYY-MM-DD","source":"newspaper","title":"..."}' >> seen.jsonl`（配信した全URL）
2. `newspaper/YYYY-MM-DD.md` にファイル出力（プロフェッショナルモード）
3. `echo '{"id":"news-YYYYMMDD",...}' >> index.jsonl`（1エントリ）

実行確認: 3操作すべて完了後に最終replyを送信する。
</HARD-GATE>

## Deep Dive Transition

When user says "深掘りして" about a specific article:
1. Extract URL and topic from the article
2. Transition to Mode 1 (Phase A) with the article as input
3. Tag the resulting topic with `source: newspaper`

## Edge Cases
- 全候補がseen.jsonlでフィルタ → 追加WebSearch（最大3回、クエリ変更しながら）
- cache/trending/が空 → 即WebSearchにフォールバック、Progressive Disclosureで待ち表示
- カテゴリweight全て0 → user-profile.yamlのデフォルト値（0.3）で全カテゴリ均等検索
